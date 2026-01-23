# Gemini CLI Package
#
# This package installs Gemini CLI with its own JavaScript runtime to ensure
# it's always available regardless of project-specific Node.js versions.

{ lib
, stdenv
, fetchurl
, nodejs_22
, bun
, cacert
, bash
, runtime ? "node"
, nodeBinName ? "gemini"
, bunBinName ? "gemini-bun"
}:

let
  version = "0.25.1";

  geminiCliTarball = fetchurl {
    url = "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-${version}.tgz";
    hash = "sha256-3oCr5RAco4Qvv3Q7aXhu8K7baZqIyd481KnR7KuKZsk=";
  };

  runtimeConfig = {
    node = {
      pkg = nodejs_22;
      runtimeBin = "${nodejs_22}/bin/node";
      npmBin = "${nodejs_22}/bin/npm";
      runCmd = "${nodejs_22}/bin/node --no-warnings --enable-source-maps";
      nativeBuildInputs = [ nodejs_22 cacert ];
      description = "Gemini CLI (Node.js) - Google AI agent in your terminal";
      binName = nodeBinName;
    };
    bun = {
      pkg = bun;
      runtimeBin = "${bun}/bin/bun";
      npmBin = "${bun}/bin/bun";
      runCmd = "${bun}/bin/bun run";
      nativeBuildInputs = [ bun cacert ];
      description = "Gemini CLI (Bun) - Google AI agent in your terminal";
      binName = bunBinName;
    };
  };

  selected = runtimeConfig.${runtime};
in
stdenv.mkDerivation rec {
  pname = if runtime == "node" then "gemini-cli" else "gemini-cli-${runtime}";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = selected.nativeBuildInputs;

  # Allow network access to fetch npm dependencies
  __noChroot = true;

  buildPhase = ''
    export HOME=$TMPDIR
    mkdir -p $HOME/.npm $HOME/.bun

    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    export NODE_EXTRA_CA_CERTS=$SSL_CERT_FILE

    ${selected.npmBin} config set cafile $SSL_CERT_FILE

    # Install gemini-cli globally with optional deps skipped
    ${selected.npmBin} install -g --prefix=$out --omit=optional ${geminiCliTarball}
  '';

  installPhase = ''
    # Remove npm-generated wrapper (has issues)
    rm -f $out/bin/gemini

    mkdir -p $out/bin
    cat > $out/bin/${selected.binName} << 'EOF'
#!${bash}/bin/bash
export NODE_PATH="$out/lib/node_modules"
export GEMINI_EXECUTABLE_PATH="$HOME/.local/bin/${selected.binName}"
exec ${selected.runCmd} "$out/lib/node_modules/@google/gemini-cli/dist/index.js" "$@"
EOF
    chmod +x $out/bin/${selected.binName}

    substituteInPlace $out/bin/${selected.binName} \
      --replace '$out' "$out"
  '';

  meta = with lib; {
    description = selected.description;
    homepage = "https://geminicli.com/";
    license = licenses.asl20;
    platforms = if runtime == "bun"
      then [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ]
      else platforms.all;
    mainProgram = selected.binName;
  };
}
