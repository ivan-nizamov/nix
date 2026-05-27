{ lib
, stdenvNoCC
, fetchgit
, makeWrapper
, alsa-utils
, bash
, coreutils
, diffutils
, findutils
, gawk
, gnugrep
, gnused
, jq
, ncurses
, openssl
, opusTools
, qrencode
, snowflake
, socat
, sox
, tor
}:

let
  runtimeInputs = [
    alsa-utils
    bash
    coreutils
    diffutils
    findutils
    gawk
    gnugrep
    gnused
    jq
    ncurses
    openssl
    opusTools
    qrencode
    socat
    sox
    tor
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "terminalphone";
  version = "1.1.6";

  src = fetchgit {
    url = "https://gitlab.com/here_forawhile/terminalphone.git";
    rev = "e1d2512e8263de871232a338caa0e764ba1e3c2f";
    hash = "sha256-I09QHbQjD7L7TUozDIIVOc5tQ0lJmM2d30X1wooxXZA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  postPatch = ''
    substituteInPlace terminalphone.sh \
      --replace-fail 'DATA_DIR="$BASE_DIR/.terminalphone"' 'DATA_DIR="''${TERMINALPHONE_DATA_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/terminalphone}"'

    patchShebangs terminalphone.sh
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 terminalphone.sh "$out/share/terminalphone/terminalphone.sh"
    install -Dm644 README.md "$out/share/doc/terminalphone/README.md"
    install -Dm644 CHANGELOG "$out/share/doc/terminalphone/CHANGELOG"
    install -Dm644 LICENSE "$out/share/licenses/terminalphone/LICENSE"

    mkdir -p "$out/libexec/terminalphone-bin"
    ln -s "${snowflake}/bin/client" "$out/libexec/terminalphone-bin/snowflake-client"

    makeWrapper "${bash}/bin/bash" "$out/bin/terminalphone" \
      --add-flags "$out/share/terminalphone/terminalphone.sh" \
      --prefix PATH : "$out/libexec/terminalphone-bin:${lib.makeBinPath runtimeInputs}"

    runHook postInstall
  '';

  meta = {
    description = "Encrypted push-to-talk voice communication over Tor hidden services";
    homepage = "https://gitlab.com/here_forawhile/terminalphone";
    license = lib.licenses.mit;
    mainProgram = "terminalphone";
    platforms = lib.platforms.linux;
  };
}
