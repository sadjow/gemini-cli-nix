# gemini-cli-nix

Nix flake for [Gemini CLI](https://geminicli.com/) - Google's open-source AI agent for your terminal.

## Features

- **Native binary**: Compiled standalone executable with Bun embedded (~76MB)
- **Always up-to-date**: Hourly automated updates via GitHub Actions
- **Three runtime options**: Native (default), Node.js 22, or Bun
- **Sandbox-compatible**: No network access during build
- **Binary caching**: Fast installs via Cachix (optional)
- **Version pinning**: Pin to specific versions, major versions, or latest

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

Three runtimes are available:

| Package | Binary | Size | Description |
|---------|--------|------|-------------|
| `gemini-cli` | `gemini` | ~76MB | **Default** - Native compiled binary, no runtime deps |
| `gemini-cli-node` | `gemini-node` | ~23MB + Node | Node.js 22 LTS runtime |
| `gemini-cli-bun` | `gemini-bun` | ~23MB + Bun | Bun runtime |

### Using Node.js runtime

```bash
nix run github:sadjow/gemini-cli-nix#gemini-cli-node
```

### Using Bun runtime

```bash
nix run github:sadjow/gemini-cli-nix#gemini-cli-bun
```

### Install multiple runtimes

```bash
nix profile install github:sadjow/gemini-cli-nix              # native -> gemini
nix profile install github:sadjow/gemini-cli-nix#gemini-cli-node  # node -> gemini-node
nix profile install github:sadjow/gemini-cli-nix#gemini-cli-bun   # bun -> gemini-bun
```

## Version Pinning

### Latest (auto-updates)

```bash
nix run github:sadjow/gemini-cli-nix
```

### Specific version

```bash
nix run github:sadjow/gemini-cli-nix?ref=v0.26.0
```

### Major version (tracks v0.x)

```bash
nix run github:sadjow/gemini-cli-nix?ref=v0
```

### In Flake Inputs

```nix
{
  inputs = {
    # Always latest (auto-updates)
    gemini-cli.url = "github:sadjow/gemini-cli-nix";

    # Pin to exact version
    gemini-cli.url = "github:sadjow/gemini-cli-nix?ref=v0.26.0";

    # Track major version (stays on v0.x)
    gemini-cli.url = "github:sadjow/gemini-cli-nix?ref=v0";
  };
}
```

## Custom Binary Names

You can customize binary names when building:

```nix
pkgs.gemini-cli.override { nativeBinName = "gem"; }
pkgs.gemini-cli-node.override { nodeBinName = "gem-node"; }
pkgs.gemini-cli-bun.override { bunBinName = "gem-bun"; }
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `nativeBinName` | `gemini` | Binary name for native runtime |
| `nodeBinName` | `gemini-node` | Binary name for Node.js runtime |
| `bunBinName` | `gemini-bun` | Binary name for Bun runtime |
| `disableTelemetry` | `false` | Disable telemetry when `true` |

### Disable Telemetry

```nix
pkgs.gemini-cli.override { disableTelemetry = true; }
```

## Binary Cache (Cachix)

For faster installs without building from source:

```bash
cachix use gemini-cli-nix
```

Or add to your Nix configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://gemini-cli-nix.cachix.org" ];
    trusted-public-keys = [ "gemini-cli-nix.cachix.org-1:DzAIhrYktyRtR1OO0KjyYEKR5hjwsdZU2NwHlEBCcvI=" ];
  };
}
```

## Troubleshooting

### Auto-update notifications

Gemini CLI may show update notifications even when installed via Nix. To disable:

1. Run `/settings` in Gemini CLI
2. Navigate to General settings
3. Disable "Auto Update Notifications"

Or add to `~/.gemini/settings.json`:

```json
{
  "general": {
    "enableAutoUpdateNotification": false
  }
}
```

### PATH issues after installation

If `gemini` command is not found:

```bash
# Check if nix-profile/bin is in PATH
echo $PATH | tr ':' '\n' | grep nix-profile

# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.nix-profile/bin:$PATH"
```

### macOS permission issues

On macOS, create a stable symlink to avoid re-granting permissions after updates:

```bash
mkdir -p ~/.local/bin
ln -sf $(which gemini) ~/.local/bin/gemini
# Add ~/.local/bin to PATH
```

## Comparison with Other Installation Methods

| Feature | npm global | Homebrew | This Flake |
|---------|------------|----------|------------|
| **Native Binary** | No | No | **Yes (default)** |
| **Latest Version** | Manual | Delayed | Hourly checks |
| **Runtime Options** | Per Node install | Node.js only | Native, Node.js, Bun |
| **Survives Node Switch** | Lost on switch | Always available | Always available |
| **Binary Cache** | None | Bottles | Cachix |
| **Declarative Config** | No | Limited | Yes |
| **Version Pinning** | Manual | Formula version | Git tags |
| **Reproducible** | No | Mostly | Yes |
| **Sandbox Builds** | N/A | N/A | Yes |

## Development

### Build locally

```bash
nix build
./result/bin/gemini --version
```

### Build Node.js variant

```bash
nix build .#gemini-cli-node
./result/bin/gemini-node --version
```

### Build Bun variant

```bash
nix build .#gemini-cli-bun
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
    └── create-version-tag.yml  # Auto-tagging
```

## Technical Details

### Native Binary (Default)

The native package compiles `gemini.js` using `bun build --compile`, creating a standalone executable with the Bun runtime embedded. This is similar to how Claude Code distributes its native binary.

### Node.js / Bun Variants

These variants use the pre-bundled `gemini.js` from [GitHub Releases](https://github.com/google-gemini/gemini-cli/releases) and run it with the respective runtime.

### Environment Variables

The wrapper script sets:
- `CI_NIX=1` - Triggers non-interactive mode, skips installation prompts
- `GEMINI_TELEMETRY_ENABLED=false` - Only when `disableTelemetry = true`

## Requirements

- Nix with flakes enabled

## License

This Nix packaging is MIT licensed.

Gemini CLI itself is [Apache 2.0 licensed](https://github.com/google-gemini/gemini-cli/blob/main/LICENSE) by Google.

## Links

- [Gemini CLI Documentation](https://geminicli.com/docs/)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [GitHub Releases](https://github.com/google-gemini/gemini-cli/releases)
