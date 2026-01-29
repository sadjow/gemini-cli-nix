# Gemini CLI Package
#
# This package installs Gemini CLI with your choice of runtime:
# - native: Compiled standalone binary using Bun (default, recommended)
# - node: Run via Node.js
# - bun: Run via Bun runtime

{ lib
, stdenv
, fetchurl
, nodejs_22
, bun
, bash
, runtime ? "node"
, nativeBinName ? "gemini"
, nodeBinName ? "gemini"
, bunBinName ? "gemini-bun"
, disableTelemetry ? false
}:

let
  version = "0.26.0";

  geminiBundled = fetchurl {
    url = "https://github.com/google-gemini/gemini-cli/releases/download/v${version}/gemini.js";
    hash = "sha256-IOx+n39JGYmHp42ObLD30H2Lgpju6bDBQ7fHLP1oc60=";
  };

  runtimeConfig = {
    native = {
      nativeBuildInputs = [ bun ];
      description = "Gemini CLI (Native Binary) - Google AI agent in your terminal";
      binName = nativeBinName;
    };
    node = {
      runCmd = "${nodejs_22}/bin/node --no-warnings --enable-source-maps";
      npmBin = "${nodejs_22}/bin/npm";
      description = "Gemini CLI (Node.js) - Google AI agent in your terminal";
      binName = nodeBinName;
    };
    bun = {
      runCmd = "${bun}/bin/bun run";
      npmBin = "${bun}/bin/bun";
      description = "Gemini CLI (Bun) - Google AI agent in your terminal";
      binName = bunBinName;
    };
  };

  selected = runtimeConfig.${runtime};
in
stdenv.mkDerivation {
  pname = if runtime == "node" then "gemini-cli"
          else "gemini-cli-${runtime}";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = if runtime == "native" then selected.nativeBuildInputs else [];

  buildPhase = lib.optionalString (runtime == "native") ''
    runHook preBuild
    cp ${geminiBundled} gemini.js
    bun build --compile gemini.js --outfile gemini-compiled
    runHook postBuild
  '';

  installPhase = if runtime == "native" then ''
    runHook preInstall

    mkdir -p $out/bin

    # Install compiled binary
    cp gemini-compiled $out/bin/gemini-raw
    chmod +x $out/bin/gemini-raw

    # Create wrapper script
    cat > $out/bin/${selected.binName} << 'WRAPPER_EOF'
#!${bash}/bin/bash
export GEMINI_EXECUTABLE_PATH="$HOME/.local/bin/${selected.binName}"
${lib.optionalString disableTelemetry "export GEMINI_TELEMETRY_ENABLED=false"}
exec "$out/bin/gemini-raw" "$@"
WRAPPER_EOF
    chmod +x $out/bin/${selected.binName}

    substituteInPlace $out/bin/${selected.binName} \
      --replace-fail '$out' "$out"

    runHook postInstall
  '' else ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp ${geminiBundled} $out/lib/gemini.js

    cat > $out/bin/${selected.binName} << 'WRAPPER_EOF'
#!${bash}/bin/bash
export GEMINI_EXECUTABLE_PATH="$HOME/.local/bin/${selected.binName}"
${lib.optionalString disableTelemetry "export GEMINI_TELEMETRY_ENABLED=false"}

export _GEMINI_NPM_WRAPPER="$(mktemp -d)/npm"
cat > "$_GEMINI_NPM_WRAPPER" << 'NPM_EOF'
#!${bash}/bin/bash
if [[ "$1" = "update" ]] || [[ "$1" = "outdated" ]] || [[ "$1" =~ ^view ]] && [[ "$2" =~ @google/gemini-cli ]]; then
    echo "Updates are managed through Nix. Current version: ${version}"
    echo "To update: nix profile upgrade '.*gemini-cli.*'"
    exit 0
fi
exec ${selected.npmBin} "$@"
NPM_EOF
chmod +x "$_GEMINI_NPM_WRAPPER"

export PATH="$(dirname "$_GEMINI_NPM_WRAPPER"):$PATH"
exec ${selected.runCmd} "$out/lib/gemini.js" "$@"
WRAPPER_EOF
    chmod +x $out/bin/${selected.binName}

    substituteInPlace $out/bin/${selected.binName} \
      --replace-fail '$out' "$out"

    runHook postInstall
  '';

  meta = with lib; {
    description = selected.description;
    homepage = "https://geminicli.com/";
    license = licenses.asl20;
    platforms = if runtime == "native" || runtime == "bun"
      then [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ]
      else platforms.all;
    mainProgram = selected.binName;
  };
}
