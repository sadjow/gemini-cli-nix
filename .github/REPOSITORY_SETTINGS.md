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

### Cachix Setup (Optional)

To enable binary caching with Cachix:

1. Create a Cachix cache at https://cachix.org
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Add a repository secret:
   - Name: `CACHIX_AUTH_TOKEN`
   - Value: Your Cachix authentication token

### Troubleshooting

If the update workflow fails with permission errors:
- Verify workflow permissions are set correctly
- Check that the GITHUB_TOKEN has write access
- Ensure branch protection allows the workflow to push

For more information, see the [GitHub Actions documentation](https://docs.github.com/en/actions/security-guides/automatic-token-authentication).
