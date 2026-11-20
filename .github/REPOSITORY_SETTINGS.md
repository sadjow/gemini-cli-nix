# Repository Settings for gemini-cli-nix

The "Update Gemini CLI Version" workflow opens a pull request for each new Gemini CLI release and squash-merges it right away with the workflow token (`GITHUB_TOKEN`). The "Build and Cache" workflow then builds the merged commit on Linux and macOS. The "Create Version Tag" workflow creates and moves the version tags only after that build succeeds. This flow needs the settings and the repository secret described below.

## Workflow Permissions

1. Go to **Settings** > **Actions** > **General**
2. Under **Workflow permissions**, select **Read and write permissions**
3. Select **Allow GitHub Actions to create and approve pull requests**
4. Click **Save**

## Pull Requests

Go to **Settings** > **General** > **Pull Requests** and select **Allow squash merging**, because the workflow merges each update pull request with the squash method.

## Branch Protection

Leave `main` without required status checks and without required reviews.

The workflow must merge the update pull request before its run ends, because the build of `main` starts when that run completes. GitHub holds the checks of a pull request that the workflow token created until a maintainer approves them, so a required status check would block every update.

## Secret

Go to **Settings** > **Secrets and variables** > **Actions**.

| Kind | Name | Value |
|------|------|-------|
| Repository secret | `CACHIX_AUTH_TOKEN` | The Cachix authentication token. The "Build and Cache" workflow uploads each build of `main` to the binary cache with this token |

## Troubleshooting

- **The "Create Pull Request" step fails with "GitHub Actions is not permitted to create or approve pull requests".** Check the settings under **Workflow permissions**.
- **The "Merge pull request" step fails.** Check that `main` has no required status checks and no required reviews, and that **Allow squash merging** is selected.
- **The checks of an update pull request wait for approval.** GitHub holds them because the workflow token created the pull request. The update does not wait for them: the "Build and Cache" workflow builds the merged commit on `main`.
