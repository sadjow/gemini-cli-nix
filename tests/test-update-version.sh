#!/usr/bin/env bash
# Run with: bash tests/test-update-version.sh [path/to/update-version.sh]
# The release lookup is answered by a stand-in curl; no network or Nix is used.
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT=${1:-"$ROOT_DIR/scripts/update-version.sh"}
if [[ ! -f "$SCRIPT" ]]; then
    printf 'Missing script under test: %s\n' "$SCRIPT" >&2
    exit 1
fi
SCRIPT=$(cd -- "$(dirname -- "$SCRIPT")" && pwd)/$(basename -- "$SCRIPT")
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/update-version-tests.XXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' EXIT

readonly PACKAGED_VERSION=1.0.0
readonly NEWER_VERSION=1.1.0
readonly UP_TO_DATE_STATUS=0
readonly ERROR_STATUS=1
readonly UPDATE_AVAILABLE_STATUS=2

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    if [[ -f "${RUN_LOG:-}" ]]; then
        printf '\nScript output:\n' >&2
        cat "$RUN_LOG" >&2
    fi
    exit 1
}

assert_equal() {
    [[ "$1" == "$2" ]] || fail "$3 (expected '$1', got '$2')"
}

make_fixture() {
    FIXTURE=$(mktemp -d "$TEST_ROOT/case.XXXXXX")
    RUN_LOG="$FIXTURE/script.log"
    CURL_ARGUMENTS_LOG="$FIXTURE/curl-arguments.log"
    : > "$CURL_ARGUMENTS_LOG"

    mkdir "$FIXTURE/repository" "$FIXTURE/bin"
    : > "$FIXTURE/repository/flake.nix"
    printf '{\n  version = "%s";\n}\n' "$PACKAGED_VERSION" > "$FIXTURE/repository/package.nix"

    cat > "$FIXTURE/bin/curl" <<'STAND_IN'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$CURL_ARGUMENTS_LOG"
if [[ -n "${REJECTED_WITH_HTTP_STATUS:-}" ]]; then
    # Like curl, stay quiet about the failure when --silent is given without
    # --show-error.
    if [[ " $* " != *' --silent '* || " $* " == *' --show-error '* ]]; then
        printf 'curl: (22) The requested URL returned error: %s\n' "$REJECTED_WITH_HTTP_STATUS" >&2
    fi
    exit 22
fi
printf '{\n  "tag_name": "v%s",\n  "name": "Release v%s"\n}\n' "$RELEASED_VERSION" "$RELEASED_VERSION"
STAND_IN

    # The check only requires these tools to exist, and the retry delays add
    # nothing to what is asserted here.
    local tool
    for tool in nix nix-prefetch-url sleep; do
        printf '#!/usr/bin/env bash\n' > "$FIXTURE/bin/$tool"
    done
    chmod +x "$FIXTURE/bin/"*
}

exit_status_of_script() {
    local status=0
    (
        cd -- "$FIXTURE/repository"
        PATH="$FIXTURE/bin:$PATH" CURL_ARGUMENTS_LOG="$CURL_ARGUMENTS_LOG" bash "$SCRIPT" "$@"
    ) > "$RUN_LOG" 2>&1 || status=$?
    printf '%s' "$status"
}

check_for_update() {
    exit_status_of_script --check
}

test_help_only_prints_usage() {
    make_fixture
    assert_equal 0 "$(exit_status_of_script --help)" 'asking for help did not succeed'
    grep -q '^Usage:' "$RUN_LOG" || fail 'asking for help did not print the usage'
    [[ ! -s "$CURL_ARGUMENTS_LOG" ]] || fail 'asking for help started an update'
}

test_up_to_date() {
    make_fixture
    unset GITHUB_TOKEN
    assert_equal "$UP_TO_DATE_STATUS" "$(RELEASED_VERSION=$PACKAGED_VERSION check_for_update)" \
        'a packaged version equal to the latest release was not reported as up to date'
}

test_update_available() {
    make_fixture
    unset GITHUB_TOKEN
    assert_equal "$UPDATE_AVAILABLE_STATUS" "$(RELEASED_VERSION=$NEWER_VERSION check_for_update)" \
        'a newer release was not reported with the update-available status'
}

test_rejected_lookup_is_an_error() {
    make_fixture
    unset GITHUB_TOKEN
    assert_equal "$ERROR_STATUS" "$(REJECTED_WITH_HTTP_STATUS=403 check_for_update)" \
        'a rejected release lookup was not reported as an error'
    grep -q 'returned error: 403' "$RUN_LOG" || fail 'the reason the lookup was rejected is missing from the output'
}

test_token_authenticates_the_lookup() {
    make_fixture
    assert_equal "$UP_TO_DATE_STATUS" \
        "$(GITHUB_TOKEN=test-token RELEASED_VERSION=$PACKAGED_VERSION check_for_update)" \
        'the authenticated lookup did not succeed'
    grep -qx 'Authorization: Bearer test-token' "$CURL_ARGUMENTS_LOG" \
        || fail 'the release lookup did not send the token'
}

test_lookup_without_token_is_anonymous() {
    make_fixture
    unset GITHUB_TOKEN
    assert_equal "$UP_TO_DATE_STATUS" "$(RELEASED_VERSION=$PACKAGED_VERSION check_for_update)" \
        'the anonymous lookup did not succeed'
    if grep -q 'Authorization' "$CURL_ARGUMENTS_LOG"; then
        fail 'the release lookup sent an Authorization header without a token'
    fi
}

run_test() {
    local label=$1
    shift
    printf 'TEST: %s\n' "$label"
    ("$@")
    printf 'PASS: %s\n' "$label"
}

run_test 'reports up to date when the packaged version is the latest release' test_up_to_date
run_test 'reports a newer release with its own exit status' test_update_available
run_test 'reports a rejected release lookup as an error, with the reason' test_rejected_lookup_is_an_error
run_test 'sends GITHUB_TOKEN with the release lookup' test_token_authenticates_the_lookup
run_test 'sends no Authorization header without GITHUB_TOKEN' test_lookup_without_token_is_anonymous
run_test 'prints the usage for --help and does nothing else' test_help_only_prints_usage
printf '\nAll update-version regression tests passed.\n'
