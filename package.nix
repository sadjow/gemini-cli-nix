# Gemini CLI Package
#
# This package builds Gemini CLI from the upstream tagged source and lockfile,
# avoiding the incomplete single-file GitHub release asset.

{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs_22
, bash
, binName ? "gemini"
, disableTelemetry ? false
}:

let
  version = "0.52.0";
  srcHash = "sha256-uF2k8L8HdmgTjtCKUShwgckP5q/acqV8M+Aar8htRoE=";
  npmDepsHash = "sha256-H7JhhMMOpGSIT/01IaHW8iqtpgMEcvXgaFXoxf+z3z4=";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    rev = "v${version}";
    hash = srcHash;
  };
in
buildNpmPackage {
  pname = "gemini-cli";
  inherit version src npmDepsHash;

  nodejs = nodejs_22;
  npmDepsFetcherVersion = 2;
  npmWorkspace = "packages/cli";
  npmInstallFlags = [ "--omit=optional" "--ignore-scripts" ];

  # Guarded so it stays a no-op inside fetchNpmDeps, which lacks node and only
  # reads the unmodified lockfile (keeping npmDepsHash stable).
  postPatch = ''
    if command -v node >/dev/null 2>&1; then
      node ${./scripts/sync-manifest-pins.cjs}
    fi
  '';

  preBuild = ''
    npm run generate
    npm run build --workspace=packages/core
    npm run build --workspace=packages/devtools
  '';

  postInstall = ''
    local pkgRoot="$out/lib/node_modules/@google/gemini-cli"
    local nm="$pkgRoot/node_modules"

    rm -rf "$nm"
    mkdir -p "$nm"
    cp -rL node_modules/. "$nm"/
    if [ -d packages/cli/node_modules ]; then
      cp -rL packages/cli/node_modules/. "$nm"/
    fi

    mkdir -p "$nm/@google"
    rm -rf "$nm/@google/gemini-cli"
    rm -rf "$nm/@google/gemini-cli-core"
    rm -rf "$nm/@google/gemini-cli-devtools"
    cp -rL packages/core "$nm/@google/gemini-cli-core"
    cp -rL packages/devtools "$nm/@google/gemini-cli-devtools"

    find "$nm" -type l -lname '*/packages/*' -delete
    if [ -d "$nm/.bin" ]; then
      find "$nm/.bin" -xtype l -delete
    fi

    rm -f $out/bin/gemini
    cat > $out/bin/${binName} << 'WRAPPER_EOF'
#!${bash}/bin/bash
export GEMINI_EXECUTABLE_PATH="$HOME/.local/bin/${binName}"
${lib.optionalString disableTelemetry "export GEMINI_TELEMETRY_ENABLED=false"}

export _GEMINI_NPM_WRAPPER="$(mktemp -d)/npm"
cat > "$_GEMINI_NPM_WRAPPER" << 'NPM_EOF'
#!${bash}/bin/bash
if [[ "$1" = "update" ]] || [[ "$1" = "outdated" ]] || [[ "$1" =~ ^view ]] && [[ "$2" =~ @google/gemini-cli ]]; then
    echo "Updates are managed through Nix. Current version: ${version}"
    echo "To update: nix profile upgrade '.*gemini-cli.*'"
    exit 0
fi
exec ${nodejs_22}/bin/npm "$@"
NPM_EOF
chmod +x "$_GEMINI_NPM_WRAPPER"

export PATH="$(dirname "$_GEMINI_NPM_WRAPPER"):$out/lib/node_modules/@google/gemini-cli/node_modules/.bin:$PATH"
exec ${nodejs_22}/bin/node --no-warnings --enable-source-maps "$out/lib/node_modules/@google/gemini-cli/dist/index.js" "$@"
WRAPPER_EOF
    chmod +x $out/bin/${binName}

    substituteInPlace $out/bin/${binName} \
      --replace-fail '$out' "$out"
  '';

  meta = with lib; {
    description = "Gemini CLI - Google AI agent in your terminal";
    homepage = "https://geminicli.com/";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = binName;
  };
}
