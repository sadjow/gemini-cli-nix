# Repository Settings for gemini-cli-nix

The "Update Gemini CLI Version" workflow opens a pull request for each new Gemini CLI release and enables auto-merge on it. GitHub merges the pull request after the Linux build and the macOS build pass. This flow needs the GitHub App, the repository variable, the repository secrets, and the repository settings described below.

## Update GitHub App

The workflow creates and merges the pull request with a token of a GitHub App, called the update App in this document. GitHub holds the checks of a pull request for approval when the workflow token (`GITHUB_TOKEN`) creates the pull request, and GitHub starts them without approval when a GitHub App token creates it.

1. Go to your account **Settings** > **Developer settings** > **GitHub Apps** > **New GitHub App**
2. Enter a **GitHub App name** and a **Homepage URL**, for example the URL of this repository
3. Under **Webhook**, clear **Active**
4. Under **Repository permissions**, set:
   - **Contents**: **Read and write**
   - **Pull requests**: **Read and write**
5. Under **Where can this GitHub App be installed?**, select **Only on this account**
6. Click **Create GitHub App**
7. On the page of the new App, copy the **Client ID**, then click **Generate a private key**. The browser downloads the private key as a `.pem` file
8. Click **Install App** and install the App on this repository only

## Variable and Secrets

Go to **Settings** > **Secrets and variables** > **Actions**.

| Kind | Name | Value |
|------|------|-------|
| Repository variable | `UPDATE_APP_CLIENT_ID` | The **Client ID** of the update App |
| Repository secret | `UPDATE_APP_PRIVATE_KEY` | The full content of the `.pem` file of the update App |
| Repository secret | `CACHIX_AUTH_TOKEN` | The Cachix authentication token. The "Build and Cache" workflow uploads each build of `main` to the binary cache with this token |

## Pull Requests

Go to **Settings** > **General** > **Pull Requests** and select:

- **Allow squash merging**, because the workflow merges each update pull request with the squash method
- **Allow auto-merge**
- **Automatically delete head branches**

## Branch Protection

Go to **Settings** > **Branches** and add a branch protection rule for `main`:

- Select **Require status checks to pass before merging**
- Add these required status checks:
  - `build (ubuntu-latest)`
  - `build (macos-latest)`

Both checks come from the "Build and Cache" workflow, which runs on every pull request to `main`.

Leave **Do not allow bypassing the above settings** cleared if repository administrators must stay able to push to `main` directly.

Without this rule, the "Enable Auto-Merge" step merges an update pull request immediately, before the builds finish.

## Troubleshooting

- **The "Create update App token" step fails.** Check that `UPDATE_APP_CLIENT_ID` and `UPDATE_APP_PRIVATE_KEY` exist, that they belong to the same App, and that the App is installed on this repository.
- **The "Enable Auto-Merge" step fails.** Check that **Allow auto-merge** is selected.
- **The checks of an update pull request wait for approval.** The pull request was created with the workflow token. Check that the "Create Pull Request" step uses the token of the update App.
- **An update pull request stays open.** A required status check failed or has not finished. If a check failed, re-run the failed job from the pull request. The pull request merges after both required status checks pass. If a newer Gemini CLI release already has its own pull request, close the older pull request.
