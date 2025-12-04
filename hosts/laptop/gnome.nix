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
      ];
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
      binding = "<Super>x";
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
    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/glass-chip-l.jxl";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/glass-chip-d.jxl";
      primary-color = "#26a269";
      secondary-color = "#000000";
    };
    "org/gnome/desktop/screensaver" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/glass-chip-l.jxl";
      primary-color = "#26a269";
      secondary-color = "#000000";
    };
    "org/gnome/desktop/session" = {
      idle-delay = 0;
    };
    "org/gnome/desktop/wm/keybindings" = {
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
      switch-to-workspace-1 = ["<Super>1"];
      switch-to-workspace-2 = ["<Super>2"];
      switch-to-workspace-3 = ["<Super>3"];
      switch-to-workspace-4 = ["<Super>4"];
    };
    "org/gnome/shell" = {
      enabled-extensions = ["space-bar@luchrioh"];
      disable-user-extensions = false; # ensure it's not disabled
    };
    "org/gnome/shell/extensions/space-bar/appearance" = {
      application-styles = ".space-bar {\\n  -natural-hpadding: 12px;\\n}\\n\\n.space-bar-workspace-label.active {\\n  margin: 0 4px;\\n  background-color: rgba(255,255,255,0.3);\\n  color: rgba(255,255,255,1);\\n  border-color: rgba(0,0,0,0);\\n  font-weight: 700;\\n  border-radius: 4px;\\n  border-width: 0px;\\n  padding: 3px 8px;\\n}\\n\\n.space-bar-workspace-label.inactive {\\n  margin: 0 4px;\\n  background-color: rgba(0,0,0,0);\\n  color: rgba(255,255,255,1);\\n  border-color: rgba(0,0,0,0);\\n  font-weight: 700;\\n  border-radius: 4px;\\n  border-width: 0px;\\n  padding: 3px 8px;\\n}\\n\\n.space-bar-workspace-label.inactive.empty {\\n  margin: 0 4px;\\n  background-color: rgba(0,0,0,0);\n  color: rgba(255,255,255,0.5);\n  border-color: rgba(0,0,0,0);\n  font-weight: 700;\n  border-radius: 4px;\n  border-width: 0px;\n  padding: 3px 8px;\n}";
    };
    "org/gnome/shell/extensions/space-bar/behavior" = {
      always-show-numbers = false;
      smart-workspace-names = true;
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
      sources = [ (pkgs.lib.gvariant.mkTuple [ "xkb" "us" ]) ];
      xkb-options = [];
    };
  };
}
