#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_API_URL="https://api.github.com/repos/google-gemini/gemini-cli/releases/latest"
readonly GITHUB_RELEASE_URL="https://github.com/google-gemini/gemini-cli/releases/download"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1 || echo "unknown"
}

get_latest_version_from_github() {
    local response
    response=$(curl -s "$GITHUB_API_URL")
    echo "$response" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1
}

fetch_gemini_js_hash() {
    local version="$1"
    local release_url="$GITHUB_RELEASE_URL/v$version/gemini.js"

    log_info "Fetching gemini.js from $release_url..." >&2
    local hash
    hash=$(nix-prefetch-url --type sha256 "$release_url" 2>/dev/null | tail -1)
    local sri_hash
    sri_hash=$(nix hash to-sri --type sha256 "$hash" 2>/dev/null)
    echo "$sri_hash" | tr -d '\n'
}

update_package_version() {
    local version="$1"
    sed -i.bak "s/version = \".*\"/version = \"$version\"/" package.nix
}

update_package_hash() {
    local hash="$1"
    sed -i.bak "s|hash = \"sha256-[^\"]*\"|hash = \"$hash\"|" package.nix
}

cleanup_backup_files() {
    rm -f package.nix.bak
}

update_to_version() {
    local new_version="$1"

    log_info "Updating to version $new_version..."

    update_package_version "$new_version"

    log_info "Fetching gemini.js hash..."
    local gemini_hash
    gemini_hash=$(fetch_gemini_js_hash "$new_version")
    if [ -z "$gemini_hash" ]; then
        log_error "Failed to fetch gemini.js hash"
        mv package.nix.bak package.nix
        exit 1
    fi

    log_info "gemini.js hash: $gemini_hash"
    update_package_hash "$gemini_hash"

    cleanup_backup_files

    log_info "Verifying build..."
    if nix build .#gemini-cli > /dev/null 2>&1; then
        log_info "Build successful!"
        return 0
    else
        log_error "Build verification failed"
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
    latest_version=$(get_latest_version_from_github)

    if [ -n "$target_version" ]; then
        latest_version="$target_version"
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
