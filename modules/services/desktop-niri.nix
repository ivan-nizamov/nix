{ config, inputs, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  userHome = config.users.users.iva.home;
  telegramDesktop = inputs.nixpkgs-unstable.legacyPackages.${system}.telegram-desktop;
  zedEditor = inputs.nixpkgs-unstable.legacyPackages.${system}.zed-editor;
  zenBrowser = inputs.zen-browser.packages.${system}.beta;
  lockCommand = pkgs.writeShellScript "niri-lock" ''
    if ${lib.getExe' pkgs.procps "pgrep"} -u "$UID" -x swaylock >/dev/null; then
      exit 0
    fi

    exec ${lib.getExe pkgs.swaylock-effects} \
      --daemonize \
      --screenshots \
      --clock \
      --indicator \
      --indicator-idle-visible \
      --indicator-radius 110 \
      --indicator-thickness 8 \
      --effect-blur 7x5 \
      --effect-vignette 0.35:0.5 \
      --fade-in 0.2 \
      --font "Ubuntu Nerd Font" \
      --font-size 24 \
      --grace 2 \
      --grace-no-mouse \
      --grace-no-touch \
      --inside-color 111111cc \
      --inside-clear-color 111111cc \
      --inside-ver-color 111111cc \
      --inside-wrong-color 111111cc \
      --line-color 00000000 \
      --ring-color ffc87fcc \
      --ring-clear-color ffc87fcc \
      --ring-ver-color 88c0d0cc \
      --ring-wrong-color bf616acc \
      --key-hl-color ebcb8bcc \
      --bs-hl-color d08770cc \
      --separator-color 00000000 \
      --text-color eceff4ff \
      --text-clear-color eceff4ff \
      --text-ver-color eceff4ff \
      --text-wrong-color eceff4ff \
      --layout-bg-color 00000000 \
      --layout-border-color 00000000 \
      --layout-text-color d8dee9ff
  '';
  zedKeymap = ''
    [
      {
        "context": "Editor",
        "bindings": {
          "ctrl-shift-v": "editor::Paste"
        }
      }
    ]
  '';
  niriConfig = ''
    input {
        touchpad {
            tap
            natural-scroll
        }

        mouse {
            natural-scroll
            accel-speed -0.176
            accel-profile "flat"
        }

        focus-follows-mouse
        workspace-auto-back-and-forth
    }

    layout {
        gaps 12
        center-focused-column "on-overflow"
        always-center-single-column
        empty-workspace-above-first

        default-column-width { proportion 0.5; }

        preset-column-widths {
            proportion 0.25
            proportion 0.5
            proportion 0.75
        }

        preset-window-heights {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        focus-ring {
            on
            width 3
            active-color "#ffc87f"
            inactive-color "#505050"
            urgent-color "#9b0000"
        }

        border {
            off
            width 3
            active-color "#ffc87f"
            inactive-color "#505050"
            urgent-color "#9b0000"
        }

        background-color "#111111"
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    window-rule {
        match app-id=r#"^zen-beta$"#
        default-column-width { proportion 0.6; }
    }

    cursor {
        hide-when-typing
        hide-after-inactive-ms 1200
    }

    clipboard {
        disable-primary
    }

    xwayland-satellite {
        path "${lib.getExe pkgs.xwayland-satellite}"
    }

    hotkey-overlay {
        skip-at-startup
        hide-not-bound
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        Mod+Return hotkey-overlay-title="Open a Terminal: alacritty" { spawn "${lib.getExe pkgs.alacritty}"; }
        Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "${lib.getExe pkgs.fuzzel}"; }
        Mod+E hotkey-overlay-title="Open Files: nautilus" { spawn "${lib.getExe pkgs.nautilus}" "--new-window"; }
        Super+Alt+L hotkey-overlay-title="Lock the Screen" { spawn "${lockCommand}"; }
        Super+Alt+S allow-when-locked=true hotkey-overlay-title=null { spawn-sh "pkill orca || exec orca"; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "${lib.getExe' pkgs.wireplumber "wpctl"} set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "${lib.getExe' pkgs.wireplumber "wpctl"} set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
        XF86AudioMute allow-when-locked=true { spawn-sh "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute allow-when-locked=true { spawn-sh "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

        XF86AudioPlay allow-when-locked=true { spawn-sh "${lib.getExe pkgs.playerctl} play-pause"; }
        XF86AudioStop allow-when-locked=true { spawn-sh "${lib.getExe pkgs.playerctl} stop"; }
        XF86AudioPrev allow-when-locked=true { spawn-sh "${lib.getExe pkgs.playerctl} previous"; }
        XF86AudioNext allow-when-locked=true { spawn-sh "${lib.getExe pkgs.playerctl} next"; }

        XF86MonBrightnessUp allow-when-locked=true { spawn "${lib.getExe pkgs.brightnessctl}" "--class=backlight" "set" "+10%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${lib.getExe pkgs.brightnessctl}" "--class=backlight" "set" "10%-"; }

        Mod+O repeat=false { toggle-overview; }
        Mod+Q repeat=false { close-window; }

        Mod+Left { focus-column-left; }
        Mod+Down { focus-window-down; }
        Mod+Up { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }

        Mod+Ctrl+Left { move-column-left; }
        Mod+Ctrl+Down { move-window-down; }
        Mod+Ctrl+Up { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H { move-column-left; }
        Mod+Ctrl+J { move-window-down; }
        Mod+Ctrl+K { move-window-up; }
        Mod+Ctrl+L { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End { focus-column-last; }
        Mod+Ctrl+Home { move-column-to-first; }
        Mod+Ctrl+End { move-column-to-last; }

        Mod+Shift+Left { focus-monitor-left; }
        Mod+Shift+Down { focus-monitor-down; }
        Mod+Shift+Up { focus-monitor-up; }
        Mod+Shift+Right { focus-monitor-right; }
        Mod+Shift+H { focus-monitor-left; }
        Mod+Shift+J { focus-monitor-down; }
        Mod+Shift+K { focus-monitor-up; }
        Mod+Shift+L { focus-monitor-right; }

        Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
        Mod+Shift+Ctrl+H { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+J { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+K { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+L { move-column-to-monitor-right; }

        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+U { focus-workspace-down; }
        Mod+I { focus-workspace-up; }
        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up { move-column-to-workspace-up; }
        Mod+Ctrl+U { move-column-to-workspace-down; }
        Mod+Ctrl+I { move-column-to-workspace-up; }
        Mod+Shift+Page_Down { move-workspace-down; }
        Mod+Shift+Page_Up { move-workspace-up; }
        Mod+Shift+U { move-workspace-down; }
        Mod+Shift+I { move-workspace-up; }

        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
        Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
        Mod+Ctrl+WheelScrollUp cooldown-ms=150 { move-column-to-workspace-up; }
        Mod+WheelScrollRight { focus-column-right; }
        Mod+WheelScrollLeft { focus-column-left; }
        Mod+Ctrl+WheelScrollRight { move-column-right; }
        Mod+Ctrl+WheelScrollLeft { move-column-left; }
        Mod+Shift+WheelScrollDown { focus-column-right; }
        Mod+Shift+WheelScrollUp { focus-column-left; }
        Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
        Mod+Ctrl+Shift+WheelScrollUp { move-column-left; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Ctrl+6 { move-column-to-workspace 6; }
        Mod+Ctrl+7 { move-column-to-workspace 7; }
        Mod+Ctrl+8 { move-column-to-workspace 8; }
        Mod+Ctrl+9 { move-column-to-workspace 9; }

        Mod+BracketLeft { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-window-height; }
        Mod+Ctrl+R { reset-window-height; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Ctrl+F { expand-column-to-available-width; }
        Mod+C { center-column; }
        Mod+Ctrl+C { center-visible-columns; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        Mod+V { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }
        Mod+W { toggle-column-tabbed-display; }

        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
        Mod+Shift+P { power-off-monitors; }
        Mod+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }
    }
  '';
  waybarConfig = ''
    [
      {
        "height": 30,
        "layer": "top",
        "position": "top",
        "spacing": 10,
        "modules-left": [
          "custom/session"
        ],
        "modules-center": [
          "clock"
        ],
        "modules-right": [
          "pulseaudio",
          "backlight",
          "network",
          "battery",
          "tray"
        ],
        "custom/session": {
          "format": " niri",
          "tooltip": false
        },
        "clock": {
          "format": "󰃰 {:%a %d %b  %H:%M}"
        },
        "pulseaudio": {
          "format": "{icon} {volume}%",
          "format-muted": "󰝟 mute",
          "format-icons": {
            "default": [
              "󰕿",
              "󰖀",
              "󰕾"
            ],
            "headphone": "󰋋",
            "headset": "󰋎"
          },
          "on-click": "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ toggle"
        },
        "backlight": {
          "format": "{icon} {percent}%",
          "format-icons": [
            "󰃞",
            "󰃟",
            "󰃠"
          ]
        },
        "network": {
          "format-wifi": "󰖩 {signalStrength}%",
          "format-ethernet": "󰈀 wired",
          "format-disconnected": "󰖪 offline",
          "tooltip-format": "{ifname}"
        },
        "battery": {
          "states": {
            "warning": 30,
            "critical": 15
          },
          "format": "{icon} {capacity}%",
          "format-charging": "󰂄 {capacity}%",
          "format-plugged": "󰚥 ac",
          "format-icons": [
            "󰂎",
            "󰁺",
            "󰁼",
            "󰁾",
            "󰂀"
          ]
        },
        "tray": {
          "spacing": 8
        }
      }
    ]
  '';
  waybarStyle = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "Ubuntu Nerd Font", "Symbols Nerd Font", sans-serif;
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background: rgba(17, 17, 17, 0.96);
      color: #f2f2f2;
    }

    #custom-session,
    #clock,
    #pulseaudio,
    #backlight,
    #network,
    #battery,
    #tray {
      background: rgba(255, 255, 255, 0.06);
      color: #f2f2f2;
      margin: 6px 0;
      padding: 0 10px;
      border-radius: 8px;
    }

    #custom-session {
      color: #ffc87f;
      font-weight: 700;
      margin-left: 10px;
    }

    #tray {
      margin-right: 10px;
    }
  '';
in
{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      nerd-fonts.ubuntu
      noto-fonts
      noto-fonts-color-emoji
    ];

    fontconfig.defaultFonts = {
      sansSerif = [
        "Ubuntu Nerd Font"
        "Symbols Nerd Font"
      ];
      serif = [
        "Ubuntu Nerd Font"
        "Symbols Nerd Font"
      ];
      monospace = [
        "JetBrainsMono Nerd Font Mono"
        "Symbols Nerd Font"
      ];
      emoji = [
        "Noto Color Emoji"
      ];
    };
  };

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    alacritty
    anki-bin
    brightnessctl
    fuzzel
    mako
    mpv
    nautilus
    playerctl
    swayidle
    swaylock-effects
    telegramDesktop
    vial
    waybar
    wl-clipboard
    wireplumber
    xwayland-satellite
    zedEditor
    zenBrowser
  ];

  environment.etc."niri/config.kdl".text = niriConfig;
  environment.etc."waybar/config.jsonc".text = waybarConfig;
  environment.etc."waybar/style.css".text = waybarStyle;
  environment.etc."zed/keymap.json".text = zedKeymap;

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          document-font-name = "Ubuntu Nerd Font 11";
          font-name = "Ubuntu Nerd Font 11";
          gtk-theme = "Adwaita-dark";
          monospace-font-name = "JetBrainsMono Nerd Font Mono 11";
        };
      };
    }
  ];

  programs.niri.enable = true;

  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    LidSwitchIgnoreInhibited = true;
    HoldoffTimeoutSec = 2;
    IdleAction = "ignore";
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    MemorySleepMode=deep
  '';

  systemd.tmpfiles.rules = [
    "d ${userHome}/.config/zed 0755 iva users - -"
    "L+ ${userHome}/.config/zed/keymap.json - - - - /etc/zed/keymap.json"
  ];

  systemd.user.services.mako = {
    description = "Mako notification daemon";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = lib.getExe pkgs.mako;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.polkit-agent = {
    description = "Polkit authentication agent";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = lib.getExe' pkgs.polkit_gnome "polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.swayidle = {
    description = "Idle manager for Niri";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = ''
        ${lib.getExe pkgs.swayidle} -w \
          timeout 601 '${lib.getExe pkgs.niri} msg action power-off-monitors' \
          timeout 600 '${lockCommand}' \
          before-sleep '${lockCommand}'
      '';
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.waybar = {
    description = "Waybar status bar";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.waybar} -c /etc/waybar/config.jsonc -s /etc/waybar/style.css";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  services.displayManager.defaultSession = "niri";
  services.displayManager.gdm.enable = true;
  services.xserver.enable = true;
}
