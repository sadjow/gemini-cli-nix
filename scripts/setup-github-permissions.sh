#!/usr/bin/env bash
set -euo pipefail

# .github/REPOSITORY_SETTINGS.md owns the setup steps, so they are not repeated here.
cat -- "$(dirname -- "${BASH_SOURCE[0]}")/../.github/REPOSITORY_SETTINGS.md"
