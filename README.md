# gemini-cli-nix

Nix flake for [Gemini CLI](https://geminicli.com/) - Google's open-source AI agent for your terminal.

## Features

- **Always up-to-date**: Hourly automated updates via GitHub Actions
- **Dual runtime support**: Node.js 22 LTS and Bun
- **Isolated runtime**: Bundled Node.js independent of system version
- **Binary caching**: Fast installs via Cachix (optional)
- **Version pinning**: Pin to specific versions, major versions, or latest

> **Note**: This package requires network access during build to fetch npm dependencies. Use `--option sandbox false` when building locally.

## Quick Start

### Run directly

```bash
nix run github:sadjow/gemini-cli-nix
```

### Install to profile

```bash
nix profile install github:sadjow/gemini-cli-nix
```

### With Home Manager

```nix
{
  inputs.gemini-cli-nix.url = "github:sadjow/gemini-cli-nix";

  # In your home configuration:
  home.packages = [ inputs.gemini-cli-nix.packages.${system}.default ];
}
```

### With NixOS

```nix
{
  inputs.gemini-cli-nix.url = "github:sadjow/gemini-cli-nix";

  # In your system configuration:
  environment.systemPackages = [ inputs.gemini-cli-nix.packages.${system}.default ];
}
```

## Runtime Selection

Two runtimes are available:

| Package | Binary | Runtime | Description |
|---------|--------|---------|-------------|
| `gemini-cli` | `gemini` | Node.js 22 | Default, most compatible |
| `gemini-cli-bun` | `gemini-bun` | Bun | Faster startup |

### Using Bun runtime

```bash
nix run github:sadjow/gemini-cli-nix#gemini-cli-bun
```

Or install:

```bash
nix profile install github:sadjow/gemini-cli-nix#gemini-cli-bun
```

## Version Pinning

### Latest (auto-updates)

```bash
nix run github:sadjow/gemini-cli-nix
```

### Specific version

```bash
nix run github:sadjow/gemini-cli-nix?ref=v0.25.1
```

### Major version (tracks v0.x)

```bash
nix run github:sadjow/gemini-cli-nix?ref=v0
```

## Binary Cache (Cachix)

For faster installs without building from source:

```bash
cachix use gemini-cli
```

Or add to your Nix configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://gemini-cli.cachix.org" ];
    trusted-public-keys = [ "gemini-cli.cachix.org-1:PLACEHOLDER_KEY" ];
  };
}
```

## Development

### Build locally

```bash
nix build --option sandbox false
./result/bin/gemini --version
```

### Build Bun variant

```bash
nix build .#gemini-cli-bun --option sandbox false
./result/bin/gemini-bun --version
```

### Update to latest version

```bash
./scripts/update-version.sh
```

### Check for updates

```bash
./scripts/update-version.sh --check
```

### Run benchmarks

```bash
./scripts/benchmark-runtimes.sh
```

## Project Structure

```
gemini-cli-nix/
├── flake.nix          # Nix flake definition
├── package.nix        # Package derivation
├── scripts/
│   ├── update-version.sh       # Version updater
│   ├── benchmark-runtimes.sh   # Runtime comparison
│   └── setup-github-permissions.sh
└── .github/workflows/
    ├── update-gemini-cli.yml   # Hourly updates
    ├── build.yml               # CI builds
    ├── test-pr.yml             # PR validation
    ├── create-version-tag.yml  # Auto-tagging
    └── flakestry-publish.yml   # Registry publish
```

## Comparison with Other Installation Methods

| Method | Auto-updates | Reproducible | Isolated Runtime |
|--------|--------------|--------------|------------------|
| `npm install -g` | Manual | No | No |
| This flake | Hourly | Yes | Yes |

## Requirements

- Nix with flakes enabled
- Node.js 20+ (bundled, not required on system)

## License

This Nix packaging is MIT licensed.

Gemini CLI itself is [Apache 2.0 licensed](https://github.com/google-gemini/gemini-cli/blob/main/LICENSE) by Google.

## Links

- [Gemini CLI Documentation](https://geminicli.com/docs/)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [npm Package](https://www.npmjs.com/package/@google/gemini-cli)
