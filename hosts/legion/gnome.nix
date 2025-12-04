{ config, pkgs, ... }:

let
  toggleNightLight = pkgs.writeShellScriptBin "toggle-night-light" ''
    # Ensure night light is enabled
    gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true

    CURRENT=$(gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature)
    if [[ "$CURRENT" == *"1000"* ]]; then
      gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 3000
      notify-send -u low "Night Light" "Warm (3000K)"
    else
      gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 1000
      notify-send -u low "Night Light" "Red (1000K)"
    fi
  '';

  toggleConservation = pkgs.writeShellScriptBin "toggle-conservation" ''
    # Path to conservation mode file
    MODE_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

    # Check current status
    STATUS=$(cat $MODE_FILE)

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

  daTranscode = pkgs.writeScriptBin "transcode" ''
    #!${pkgs.zsh}/bin/zsh

    # =============================================================================
    # Bulk Transcode for DaVinci Resolve (Linux Free Version)
    # =============================================================================

    set -e

    # 0. Check Dependencies
    if ! command -v ffmpeg &> /dev/null;
        then
        echo "Error: ffmpeg is not installed or not in PATH."
        exit 1
    fi

    # 1. Check Input
    if [[ -z "$1" ]]; then
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
    VIDEO_EXTS=("mp4" "mkv" "mov" "webm" "avi" "m4v" "mts" "flv")
    AUDIO_EXTS=("mp3" "aac" "wav" "flac" "m4a" "ogg" "wma")
    ALL_EXTS=($VIDEO_EXTS $AUDIO_EXTS)
    EXT_GLOB="''${(j:|:)ALL_EXTS}"

    # Enable extended globbing and null glob (prevents errors if no files match)
    setopt extended_glob null_glob

    echo "Scanning '$SOURCE_DIR'..."

    # 3. Process Files
    # Zsh glob qualifier (#i) makes the glob case-insensitive
    for file in "$SOURCE_DIR"/*.(#i)(''${~EXT_GLOB}); do

        # Skip directories just in case
        [[ -d "$file" ]] && continue

        filename="''${file:t}"       # e.g., video.mp4
        basename="''${filename:r}"   # e.g., video
        ext_lower="''${filename:e:l}" # e.g., mp4 (lowercase)

        # Determine type
        is_video=0
        if [[ ''${VIDEO_EXTS[(r)$ext_lower]} == "$ext_lower" ]]; then
            is_video=1
        fi

        if (( is_video )); then
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

        if (( is_video )); then
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
in
{
  home.username = "iva";
  home.homeDirectory = "/home/iva";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11"; # Aligned with nixos-unstable's expected upcoming release.

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    libnotify
    toggleNightLight
    toggleConservation
    daTranscode
    ffmpeg-full
  ];

  programs.zed-editor.enable = true;
  xdg.configFile."zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/dotfiles/zed/settings.json";
  xdg.configFile."zed/settings.json".force = true;
  xdg.configFile."zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/dotfiles/zed/keymap.json";
  xdg.configFile."zed/keymap.json".force = true;

  # Desktop specific GNOME settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "red";
      cursor-size = 35;
      cursor-theme = "macOS";
      icon-theme = "Adwaita";
      show-battery-percentage = true;
    };
    "org/gnome/desktop/peripherals/keyboard" = {
      numlock-state = false;
    };
    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
      natural-scroll = true;
      speed = -0.176; # Approximately
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true; # Added as it was in dump, even if desktop
    };
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-temperature = pkgs.lib.gvariant.mkUint32 1000;
      night-light-schedule-automatic = false;
      night-light-schedule-from = 0.0;
      night-light-schedule-to = 24.0;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-type = "nothing";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
      ];
      home = ["<Super>f"];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>e";
      command = "emacs";
      name = "Emacs";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>z";
      command = "zen";
      name = "Zen Browser";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super>t";
      command = "ghostty";
      name = "Ghostty Terminal";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Shift><Control>Escape";
      command = "gnome-system-monitor";
      name = "System Monitor";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
      binding = "<Super>n";
      command = "${toggleNightLight}/bin/toggle-night-light";
      name = "Toggle Night Light";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
      binding = "<Super>c";
      command = "${toggleConservation}/bin/toggle-conservation";
      name = "Toggle Battery Conservation";
    };
    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file://${./backgrounds/wallpaper.jpg}";
      picture-uri-dark = "file://${./backgrounds/wallpaper.jpg}";
      primary-color = "#26a269";
      secondary-color = "#000000";
    };
    "org/gnome/desktop/screensaver" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file://${./backgrounds/wallpaper.jpg}";
      primary-color = "#26a269";
      secondary-color = "#000000";
    };
    "org/gnome/desktop/session" = {
      idle-delay = 0;
    };
    "org/gnome/desktop/wm/keybindings" = {
      close = ["<Super>q"];
      minimize = ["<Super>h"];
      maximize = ["<Super>Up"];
      unmaximize = ["<Super>Down" "<Alt>F5"];
      toggle-fullscreen = ["F11"];
      move-to-monitor-down = ["<Super><Shift>Down"];
      move-to-monitor-left = ["<Super><Shift>Left"];
      move-to-monitor-right = ["<Super><Shift>Right"];
      move-to-monitor-up = ["<Super><Shift>Up"];
      move-to-workspace-1 = ["<Super><Shift>1"];
      move-to-workspace-10 = ["<Super><Shift>0"];
      move-to-workspace-2 = ["<Super><Shift>2"];
      move-to-workspace-3 = ["<Super><Shift>3"];
      move-to-workspace-4 = ["<Super><Shift>4"];
      move-to-workspace-5 = ["<Super><Shift>5"];
      move-to-workspace-6 = ["<Super><Shift>6"];
      move-to-workspace-7 = ["<Super><Shift>7"];
      move-to-workspace-8 = ["<Super><Shift>8"];
      move-to-workspace-9 = ["<Super><Shift>9"];
      switch-applications = ["<Super>Tab" "<Alt>Tab"];
      switch-input-source = ["<Super>space"];
      switch-input-source-backward = ["<Shift><Super>space"];
      switch-to-workspace-1 = ["<Super>1"];
      switch-to-workspace-2 = ["<Super>2"];
      switch-to-workspace-3 = ["<Super>3"];
      switch-to-workspace-4 = ["<Super>4"];
      switch-to-workspace-5 = ["<Super>5"];
      switch-to-workspace-6 = ["<Super>6"];
      switch-to-workspace-7 = ["<Super>7"];
      switch-to-workspace-8 = ["<Super>8"];
      switch-to-workspace-9 = ["<Super>9"];
    };
    "org/gnome/shell" = {
      enabled-extensions = ["space-bar@luchrioh"];
      disable-user-extensions = false; # ensure it's not disabled
    };
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [];
      switch-to-application-2 = [];
      switch-to-application-3 = [];
      switch-to-application-4 = [];
      switch-to-application-5 = [];
      switch-to-application-6 = [];
      switch-to-application-7 = [];
      switch-to-application-8 = [];
      switch-to-application-9 = [];
    };
    "org/gnome/shell/extensions/space-bar/appearance" = {
      application-styles = ".space-bar {\\n  -natural-hpadding: 12px;\\n}\\n\\n.space-bar-workspace-label.active {\\n  margin: 0 4px;\\n  background-color: rgba(255,255,255,0.3);\\n  color: rgba(255,255,255,1);\\n  border-color: rgba(0,0,0,0);\\n  font-weight: 700;\\n  border-radius: 4px;\\n  border-width: 0px;\\n  padding: 3px 8px;\\n}\\n\\n.space-bar-workspace-label.inactive {\\n  margin: 0 4px;\\n  background-color: rgba(0,0,0,0);\\n  color: rgba(255,255,255,1);\\n  border-color: rgba(0,0,0,0);\\n  font-weight: 700;\\n  border-radius: 4px;\\n  border-width: 0px;\\n  padding: 3px 8px;\\n}\\n\\n.space-bar-workspace-label.inactive.empty {\\n  margin: 0 4px;\\n  background-color: rgba(0,0,0,0);\n  color: rgba(255,255,255,0.5);\n  border-color: rgba(0,0,0,0);\n  font-weight: 700;\n  border-radius: 4px;\n  border-width: 0px;\n  padding: 3px 8px;\n}";
      active-workspace-font-weight = "700";
      empty-workspace-font-weight = "700";
      inactive-workspace-font-weight = "700";
    };
    "org/gnome/shell/extensions/space-bar/behavior" = {
      always-show-numbers = true;
      smart-workspace-names = false;
      indicator-style = "workspaces-bar";
      position = "left";
      scroll-wheel = "panel";
      toggle-overview = false;
    };
    "org/gnome/shell/extensions/space-bar/shortcuts" = {
      enable-move-to-workspace-shortcuts = true;
      enable-activate-workspace-shortcuts = true;
      activate-empty-key = ["<Super>j"];
      back-and-forth = false;
    };
    "org/gnome/tweaks" = {
      show-extensions-notice = false;
    };
    "org/gnome/mutter" = {
      dynamic-workspaces = true;
    };
    "org/gtk/settings/file-chooser" = {
      date-format = "regular";
      location-mode = "path-bar";
      show-hidden = false;
      show-size-column = true;
      show-type-column = true;
      sidebar-width = 167;
      sort-column = "name";
      sort-directories-first = false;
      sort-order = "ascending";
      type-format = "category";
    };
    "org/gnome/desktop/input-sources" = {
      sources = [ (pkgs.lib.gvariant.mkTuple [ "xkb" "us" ]) (pkgs.lib.gvariant.mkTuple [ "xkb" "ru" ]) ];
      xkb-options = [];
    };
  };
}
