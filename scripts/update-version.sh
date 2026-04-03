#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_API_URL="https://api.github.com/repos/google-gemini/gemini-cli/releases/latest"
readonly GITHUB_SOURCE_URL="https://codeload.github.com/google-gemini/gemini-cli/tar.gz/refs/tags"

readonly MAX_RETRIES=3
readonly RETRY_BASE_DELAY=2
readonly NPM_DEPS_FETCHER_VERSION=2

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

retry() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        local result
        result=$("$@") && [ -n "$result" ] && { echo "$result"; return 0; }

        if ((attempt < max_attempts)); then
            local delay=$((base_delay ** attempt))
            log_warn "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..." >&2
            sleep "$delay"
        fi
    done

    return 1
}

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1 || echo "unknown"
}

fetch_latest_version() {
    curl -sf --max-time 10 "$GITHUB_API_URL" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1
}

get_latest_version_from_github() {
    retry "$MAX_RETRIES" "$RETRY_BASE_DELAY" fetch_latest_version
}

prefetch_unpacked_url() {
    nix-prefetch-url --type sha256 --unpack "$1" 2>/dev/null | tail -1
}

fetch_source_hash() {
    local version="$1"
    local source_url="$GITHUB_SOURCE_URL/v$version"

    log_info "Fetching source hash from $source_url..." >&2
    local hash
    hash=$(retry "$MAX_RETRIES" "$RETRY_BASE_DELAY" prefetch_unpacked_url "$source_url")
    local sri_hash
    sri_hash=$(nix hash to-sri --type sha256 "$hash" 2>/dev/null)
    echo "$sri_hash" | tr -d '\n'
}

prefetch_npm_deps_from_lockfile() {
    local lockfile="$1"

    if command -v prefetch-npm-deps >/dev/null 2>&1; then
        NPM_FETCHER_VERSION="$NPM_DEPS_FETCHER_VERSION" prefetch-npm-deps "$lockfile" 2>/dev/null | tail -1
    else
        NPM_FETCHER_VERSION="$NPM_DEPS_FETCHER_VERSION" nix run nixpkgs#prefetch-npm-deps -- "$lockfile" 2>/dev/null | tail -1
    fi
}

prefetch_npm_deps_for_version() {
    local version="$1"
    local source_url="$GITHUB_SOURCE_URL/v$version"

    (
        set -euo pipefail
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT

        curl -fsSL "$source_url" | tar -xzf - -C "$tmp"
        root=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)

        prefetch_npm_deps_from_lockfile "$root/package-lock.json"
    ) | tail -1
}

fetch_npm_deps_hash() {
    local version="$1"

    log_info "Fetching npm dependency hash from upstream lockfile..." >&2
    retry "$MAX_RETRIES" "$RETRY_BASE_DELAY" prefetch_npm_deps_for_version "$version" | tr -d '\n'
}

update_package_metadata() {
    local version="$1"
    local source_hash="$2"
    local npm_deps_hash="$3"
    local escaped_version
    local escaped_source_hash
    local escaped_npm_deps_hash

    escaped_version=$(escape_sed_replacement "$version")
    escaped_source_hash=$(escape_sed_replacement "$source_hash")
    escaped_npm_deps_hash=$(escape_sed_replacement "$npm_deps_hash")

    sed -i.bak \
        -e "s|version = \"[^\"]*\"|version = \"$escaped_version\"|" \
        -e "s|srcHash = \"sha256-[^\"]*\"|srcHash = \"$escaped_source_hash\"|" \
        -e "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"$escaped_npm_deps_hash\"|" \
        package.nix
}

cleanup_backup_files() {
    rm -f package.nix.bak
}

verify_package() {
    log_info "Verifying build..."
    nix build .#gemini-cli > /dev/null 2>&1 || return 1

    log_info "Verifying runtime..."
    ./result/bin/gemini --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' > /dev/null 2>&1
}

update_to_version() {
    local new_version="$1"

    log_info "Updating to version $new_version..."

    local source_hash
    source_hash=$(fetch_source_hash "$new_version")
    if [ -z "$source_hash" ]; then
        log_error "Failed to fetch source hash"
        exit 1
    fi

    local npm_deps_hash
    npm_deps_hash=$(fetch_npm_deps_hash "$new_version")
    if [ -z "$npm_deps_hash" ]; then
        log_error "Failed to fetch npm dependency hash"
        exit 1
    fi

    log_info "Source hash: $source_hash"
    log_info "npmDepsHash: $npm_deps_hash"

    update_package_metadata "$new_version" "$source_hash" "$npm_deps_hash"

    if verify_package; then
        cleanup_backup_files
        log_info "Build and runtime verification successful!"
        return 0
    else
        log_error "Build or runtime verification failed"
        mv package.nix.bak package.nix
        return 1
    fi
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "package.nix" ]; then
        log_error "flake.nix or package.nix not found. Please run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v nix-prefetch-url >/dev/null 2>&1 || { log_error "nix-prefetch-url is required but not installed."; exit 1; }
    command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to specific version"
    echo "  --check           Only check for updates, don't apply"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update to latest version"
    echo "  $0 --check            # Check if update is available"
    echo "  $0 --version 0.26.0   # Update to specific version"
}

parse_arguments() {
    local target_version=""
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                target_version="$2"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    echo "$target_version|$check_only"
}

update_flake_lock() {
    if command -v nix >/dev/null 2>&1; then
        log_info "Updating flake.lock..."
        nix flake update
    fi
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat package.nix flake.lock 2>/dev/null || true
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local args
    args=$(parse_arguments "$@")
    local target_version
    target_version=$(echo "$args" | cut -d'|' -f1)
    local check_only
    check_only=$(echo "$args" | cut -d'|' -f2)

    local current_version
    current_version=$(get_current_version)

    local latest_version
    if [ -n "$target_version" ]; then
        latest_version="$target_version"
    else
        latest_version=$(get_latest_version_from_github) || true
        if [ -z "$latest_version" ]; then
            log_error "Failed to fetch latest version from GitHub after $MAX_RETRIES attempts"
            exit 1
        fi
    fi

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date!"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version -> $latest_version"
        exit 1
    fi

    update_to_version "$latest_version"

    log_info "Successfully updated gemini-cli from $current_version to $latest_version"

    update_flake_lock
    show_changes
}

main "$@"
