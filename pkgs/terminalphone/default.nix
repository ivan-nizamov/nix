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
, pipewire
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
    pipewire
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

    substituteInPlace terminalphone.sh \
      --replace-fail 'aplay -f S16_LE -r "$rate" -c 1 -q "$infile" 2>/dev/null' 'pw-play --raw --rate "$rate" --channels 1 --format s16 "$infile" 2>/dev/null || true' \
      --replace-fail 'aplay -f S16_LE -r 48000 -c 1 -q 2>/dev/null || true' 'pw-play --raw --rate 48000 --channels 1 --format s16 - 2>/dev/null || true'

    substituteInPlace terminalphone.sh \
      --replace-fail 'audio_deps+=(arecord aplay)' 'audio_deps+=(arecord pw-play)' \
      --replace-fail 'all_deps=(tor opusenc opusdec sox socat openssl arecord aplay)' 'all_deps=(tor opusenc opusdec sox socat openssl arecord pw-play)'

    substituteInPlace terminalphone.sh \
      --replace-fail '    # Encode → encrypt → send' '    # Normalize quiet microphone input before encoding.
    if [ -s "$raw_file" ]; then
        local norm_file="$AUDIO_DIR/tx_norm_''${_id}.tmp"
        if sox -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 "$raw_file" \
            -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 "$norm_file" gain -n -3 2>/dev/null; then
            mv "$norm_file" "$raw_file"
        else
            rm -f "$norm_file" 2>/dev/null
        fi
    fi

    # Encode → encrypt → send' \
      --replace-fail '    echo -e "  ''${DIM}Recorded $raw_size bytes of raw audio''${NC}"
' '    echo -e "  ''${DIM}Recorded $raw_size bytes of raw audio''${NC}"

    local norm_file="$AUDIO_DIR/test_norm_''${_tid}.tmp"
    if sox -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 "$raw_file" \
        -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 "$norm_file" gain -n -3 2>/dev/null; then
        mv "$norm_file" "$raw_file"
    else
        rm -f "$norm_file" 2>/dev/null
    fi
'

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
