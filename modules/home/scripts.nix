{pkgs, ...}: let
  toggleNightLight = pkgs.writeShellApplication {
    name = "toggle-night-light";
    runtimeInputs = [pkgs.glib];
    text = ''
      # Ensure night light is enabled
      gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true

      CURRENT=$(gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature)
      if [[ "$CURRENT" == *"1000"* ]]; then
        gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 2000
      elif [[ "$CURRENT" == *"2000"* ]]; then
        gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 3000
      else
        gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 1000
      fi
    '';
  };

  toggleConservation = pkgs.writeShellApplication {
    name = "toggle-conservation";
    runtimeInputs = [pkgs.coreutils pkgs.libnotify pkgs.sudo];
    text = ''
      # Path to conservation mode file
      MODE_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

      # Check current status
      STATUS=$(cat "$MODE_FILE")

      if [ "$STATUS" = "1" ]; then
        # Currently enabled, so disable it (charge to 100%)
        sudo lenovo-conservation 0
        notify-send -u critical "Battery" "Conservation DISABLED\nCharging to 100%"
      else
        # Currently disabled, so enable it (limit to 60%)
        sudo lenovo-conservation 1
        notify-send -u low "Battery" "Conservation ENABLED\nLimit 60%"
      fi
    '';
  };

  vosk = pkgs.python3Packages.buildPythonPackage rec {
    pname = "vosk";
    version = "0.3.45";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/fc/ca/83398cfcd557360a3d7b2d732aee1c5f6999f68618d1645f38d53e14c9ff/vosk-0.3.45-py3-none-manylinux_2_12_x86_64.manylinux2010_x86_64.whl";
      sha256 = "17v14rfy5qdcfcvc4j5zlk1hlin5iknnhdaliwkxg6a37h4jbq15";
    };
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    propagatedBuildInputs = with pkgs.python3Packages; [
      requests
      cffi
      tqdm
      websockets
      srt
    ];
    doCheck = false;
  };

  nerdDictationPkg = pkgs.stdenv.mkDerivation {
    pname = "nerd-dictation";
    version = "master";
    src = pkgs.fetchFromGitHub {
      owner = "ideasman42";
      repo = "nerd-dictation";
      rev = "41f372789c640e01bb6650339a78312661530843";
      sha256 = "1sx3s3nzp085a9qx1fj0k5abcy000i758xbapp6wd4vgaap8fdn6";
    };
    buildInputs = [pkgs.python3 vosk];
    nativeBuildInputs = [pkgs.makeWrapper];
    installPhase = ''
      mkdir -p $out/bin
      cp nerd-dictation $out/bin/nerd-dictation
      chmod +x $out/bin/nerd-dictation
      wrapProgram $out/bin/nerd-dictation \
        --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.xdotool pkgs.pulseaudio]} \
        --prefix PYTHONPATH : "${pkgs.python3Packages.makePythonPath [vosk]}"
    '';
  };

  toggleNerdDictation = pkgs.writeShellApplication {
    name = "toggle-nerd-dictation";
    runtimeInputs = [pkgs.procps pkgs.libnotify pkgs.glib];
    text = ''
      MODEL_DIR="$HOME/.config/nerd-dictation/model"
      if [ ! -d "$MODEL_DIR" ]; then
        notify-send -u critical "Nerd Dictation" "Model not found at $MODEL_DIR.\nPlease download a VOSK model."
        exit 1
      fi

      if pgrep -f "nerd-dictation.*begin"; then
        ${nerdDictationPkg}/bin/nerd-dictation end
        pkill -f "nerd-dictation.*begin"
        gsettings set org.gnome.desktop.interface accent-color 'red'
      else
        ${nerdDictationPkg}/bin/nerd-dictation begin &
        gsettings set org.gnome.desktop.interface accent-color 'green'
      fi
    '';
  };

  daTranscode = pkgs.writeShellApplication {
    name = "transcode";
    runtimeInputs = [pkgs.ffmpeg-full pkgs.coreutils];
    text = ''
      # =============================================================================
      # Bulk Transcode for DaVinci Resolve (Linux Free Version)
      # =============================================================================

      # 0. Check Dependencies
      if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg is not installed or not in PATH."
        exit 1
      fi

      # 1. Check Input
      if [[ -z "''${1:-}" ]]; then
        echo "Usage: $(basename "$0") <media_directory>"
        exit 1
      fi

      SOURCE_DIR="''${1%/}" # Remove trailing slash
      TRANSCODED_DIR="$SOURCE_DIR/Transcoded"

      if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "Error: Directory '$SOURCE_DIR' does not exist."
        exit 1
      fi

      mkdir -p "$TRANSCODED_DIR"

      # 2. Define Extensions
      VIDEO_EXTS=(mp4 mkv mov webm avi m4v mts flv)
      AUDIO_EXTS=(mp3 aac wav flac m4a ogg wma)

      shopt -s nullglob

      echo "Scanning '$SOURCE_DIR'..."

      # 3. Process Files
      for file in "$SOURCE_DIR"/*; do
        # Skip directories just in case
        [[ -d "$file" ]] && continue

        filename=$(basename "$file")
        ext="''${filename##*.}"
        if [[ "$ext" == "$filename" ]]; then
          continue
        fi

        ext_lower="''${ext,,}"

        is_video=0
        for ext_name in "''${VIDEO_EXTS[@]}"; do
          if [[ "$ext_lower" == "$ext_name" ]]; then
            is_video=1
            break
          fi
        done

        is_audio=0
        if [[ "$is_video" -eq 0 ]]; then
          for ext_name in "''${AUDIO_EXTS[@]}"; do
            if [[ "$ext_lower" == "$ext_name" ]]; then
              is_audio=1
              break
            fi
          done
          if [[ "$is_audio" -eq 0 ]]; then
            continue
          fi
        fi

        basename="''${filename%.*}"
        if [[ "$is_video" -eq 1 ]]; then
          # DNxHR HQ .mov (Supports 4:2:2 8-bit/10-bit)
          output_file="$TRANSCODED_DIR/''${basename}_davinci.mov"
        else
          # PCM WAV 16-bit
          output_file="$TRANSCODED_DIR/''${basename}.wav"
        fi

        # Skip if exists
        if [[ -f "$output_file" ]]; then
          echo "[SKIP] $filename"
          continue
        fi

        echo -n "[PROC] Transcoding $filename... "

        if [[ "$is_video" -eq 1 ]]; then
          # Video: DNxHR HQ, PCM Audio
          if ffmpeg -v error -stats -i "$file" \
              -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
              -c:a pcm_s16le \
              "$output_file" < /dev/null; then
            echo "Done"
          else
            echo "FAILED"
            # Clean up partial file
            rm -f "$output_file"
          fi
        else
          # Audio: PCM WAV
          if ffmpeg -v error -stats -i "$file" \
              -vn \
              -c:a pcm_s16le \
              "$output_file" < /dev/null; then
            echo "Done"
          else
            echo "FAILED"
            rm -f "$output_file"
          fi
        fi
      done

      echo "All operations complete."
    '';
  };

  xpPenLauncher = pkgs.writeShellApplication {
    name = "xp-pen-launcher";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.polkit
      pkgs.libsForQt5.xp-pen-deco-01-v2-driver
    ];
    text = ''
      # Launcher for XP-Pen driver with root privileges and Wayland/X11 support

      # Ensure the elevated process can find the user's runtime dir (for Wayland socket)
      export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

      if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        platform="wayland"
      else
        platform="xcb"
      fi

      pkexec env \
        "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
        "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}" \
        "DISPLAY=${DISPLAY:-}" \
        "QT_QPA_PLATFORM=$platform" \
        xp-pen-deco-01-v2-driver
    '';
  };

  davinciNvidia = pkgs.writeShellApplication {
    name = "davinci-nvidia";
    text = ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      export QT_QPA_PLATFORM=xcb
      exec ${pkgs.davinci-resolve}/bin/davinci-resolve "$@"
    '';
  };

  lenovoConservation = pkgs.writeShellApplication {
    name = "lenovo-conservation";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if [ "''${1:-}" = "1" ]; then
        echo 1 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
      else
        echo 0 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
      fi
    '';
  };
in {
  inherit
    toggleNightLight
    toggleConservation
    toggleNerdDictation
    daTranscode
    xpPenLauncher
    nerdDictationPkg
    davinciNvidia
    lenovoConservation
    ;
}
