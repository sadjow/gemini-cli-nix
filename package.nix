# Gemini CLI Package
#
# This package installs Gemini CLI using the official bundled JS from Google's releases,
# running via Node.js 22 (the officially supported runtime).

{ lib
, stdenv
, fetchurl
, nodejs_22
, bash
, binName ? "gemini"
, disableTelemetry ? false
}:

let
  version = "0.29.3";

  geminiBundled = fetchurl {
    url = "https://github.com/google-gemini/gemini-cli/releases/download/v${version}/gemini.js";
    hash = "sha256-L4dVtedO7B3us+TWbtYgCvZ/9mUnLq1guKLLo8uXd5A=";
  };
in
stdenv.mkDerivation {
  pname = "gemini-cli";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp ${geminiBundled} $out/lib/gemini.js

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

export PATH="$(dirname "$_GEMINI_NPM_WRAPPER"):$PATH"
exec ${nodejs_22}/bin/node --no-warnings --enable-source-maps "$out/lib/gemini.js" "$@"
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
