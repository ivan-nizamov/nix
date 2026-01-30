{pkgs, ...}: {
  imports = [
    ../../home/gnome/common.nix
  ];

  # Desktop specific GNOME settings
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
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
      command = "toggle-night-light";
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
    "org/gnome/shell/extensions/space-bar/behavior" = {
      always-show-numbers = false;
      smart-workspace-names = true;
      toggle-overview = false;
    };
    "org/gnome/desktop/input-sources" = {
      sources = [(pkgs.lib.gvariant.mkTuple ["xkb" "us"])];
      xkb-options = [];
    };
  };
}
