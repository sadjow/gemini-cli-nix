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
  version = "0.35.3";
  srcHash = "sha256-tAv34dHEf9uK6A/d+zkYYB7FVPviRnjYrP5E23b9OXw=";
  npmDepsHash = "sha256-gJJ2UD6m5vwUwYoYU8L4bjefrTX9CMWRYz4YTHi6Q/M=";

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

  dontNpmPrune = true;

  buildPhase = ''
    runHook preBuild

    npm run build --workspace @google/gemini-cli-core
    npm run build --workspace @google/gemini-cli

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@google $out/bin

    cp -rL node_modules $out/lib/
    rm -rf $out/lib/node_modules/@google/gemini-cli
    rm -rf $out/lib/node_modules/@google/gemini-cli-core
    cp -r packages/cli $out/lib/node_modules/@google/gemini-cli
    cp -r packages/core $out/lib/node_modules/@google/gemini-cli-core

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

export PATH="$(dirname "$_GEMINI_NPM_WRAPPER"):$out/lib/node_modules/.bin:$PATH"
exec ${nodejs_22}/bin/node --no-warnings --enable-source-maps "$out/lib/node_modules/@google/gemini-cli/dist/index.js" "$@"
WRAPPER_EOF
    chmod +x $out/bin/${binName}

    substituteInPlace $out/bin/${binName} \
      --replace-fail '$out' "$out"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Gemini CLI - Google AI agent in your terminal";
    homepage = "https://geminicli.com/";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = binName;
  };
}
