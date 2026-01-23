#!/usr/bin/env bash
set -euo pipefail

cat << 'EOF'
# GitHub Repository Settings for gemini-cli-nix

This script outputs the manual steps required to configure GitHub Actions
permissions for automated PR creation and merging.

## Required Settings

### 1. Workflow Permissions

Navigate to: Settings > Actions > General > Workflow permissions

Enable:
- [x] Read and write permissions
- [x] Allow GitHub Actions to create and approve pull requests

### 2. Branch Protection (Optional but Recommended)

Navigate to: Settings > Branches > Add branch protection rule

For the `main` branch:
- [x] Require a pull request before merging
- [x] Require status checks to pass before merging
  - Add required status checks: `build (ubuntu-latest, gemini-cli)`, `build (macos-latest, gemini-cli)`
- [x] Allow auto-merge

### 3. Secrets (Optional - for Cachix)

Navigate to: Settings > Secrets and variables > Actions

Add repository secrets:
- `CACHIX_AUTH_TOKEN`: Your Cachix authentication token (if using Cachix)

## Verification

After configuring:

1. Trigger the update workflow manually:
   Actions > Update Gemini CLI Version > Run workflow

2. Verify the workflow can:
   - Check for new versions
   - Create pull requests
   - Enable auto-merge

EOF

mkdir -p .github

cat > .github/REPOSITORY_SETTINGS.md << 'SETTINGS_EOF'
# Repository Settings for gemini-cli-nix

## Workflow Permissions

The automated update workflow requires specific GitHub Actions permissions.

### Required Settings

1. Go to **Settings** > **Actions** > **General**
2. Under **Workflow permissions**, select:
   - **Read and write permissions**
   - Check **Allow GitHub Actions to create and approve pull requests**
3. Click **Save**

### Branch Protection (Recommended)

1. Go to **Settings** > **Branches**
2. Add a branch protection rule for `main`:
   - Require pull request reviews
   - Require status checks to pass
   - Allow auto-merge

### Troubleshooting

If the update workflow fails with permission errors:
- Verify workflow permissions are set correctly
- Check that the GITHUB_TOKEN has write access
- Ensure branch protection allows the workflow to push

For more information, see the [GitHub Actions documentation](https://docs.github.com/en/actions/security-guides/automatic-token-authentication).
SETTINGS_EOF

echo ""
echo "Created .github/REPOSITORY_SETTINGS.md"
echo ""
echo "Please follow the steps above to configure your repository."
