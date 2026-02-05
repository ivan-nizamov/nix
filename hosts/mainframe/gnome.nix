{config, pkgs, inputs, ...}: let
  scripts = import ../../modules/home/scripts.nix {inherit pkgs;};
in {
  imports = [
    ../../home/gnome/common.nix
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  home.packages = with pkgs; [
    scripts.toggleConservation
    scripts.xpPenLauncher
    scripts.nerdDictationPkg
    scripts.toggleNerdDictation
    # gnomeExtensions.shaderpaper-gnome
    gnomeExtensions.hibernate-status-button
  ];

  programs.openclaw = {
    enable = true;

    bundledPlugins.gogcli = {
      enable = true;
      config.env.GOG_ACCOUNT = "ivan.nizamov@gmail.com";
    };

    config = {
      agents.defaults = {
        model.primary = "openai-codex/gpt-5.2-codex";
        models = {
          "openai-codex/gpt-5.2-codex" = {};
          "openai-codex/gpt-5.2" = {};
        };
        workspace = "/home/iva/.openclaw/workspace";
        memorySearch = {
          provider = "local";
          fallback = "none";
          local.modelPath = "hf:ggml-org/embeddinggemma-300M-GGUF/embeddinggemma-300M-Q8_0.gguf";
          chunking = {
            tokens = 64;
            overlap = 16;
          };
        };
        compaction.mode = "safeguard";
        thinkingDefault = "high";
        maxConcurrent = 4;
        subagents.maxConcurrent = 8;
      };

      auth.profiles."openai-codex:default" = {
        provider = "openai-codex";
        mode = "oauth";
      };

      channels = {
        whatsapp = {
          dmPolicy = "allowlist";
          selfChatMode = true;
          allowFrom = [
            "+40738030141"
          ];
          groupPolicy = "allowlist";
          mediaMaxMb = 50;
          debounceMs = 0;
        };

        telegram = {
          enabled = true;
          dmPolicy = "pairing";
          tokenFile = "/home/iva/.secrets/telegram_bot_token";
          groupPolicy = "allowlist";
          streamMode = "partial";
        };
      };

      commands = {
        native = "auto";
        nativeSkills = "auto";
        restart = true;
      };

      env.vars = {
        GGML_VULKAN_DEVICE = "1";
      };

      gateway = {
        port = 18789;
        mode = "local";
        bind = "loopback";
        auth.mode = "token";
        tailscale = {
          mode = "off";
          resetOnExit = false;
        };
      };

      messages.ackReactionScope = "group-mentions";

      plugins.entries = {
        telegram.enabled = true;
        whatsapp.enabled = true;
      };

      skills.install.nodeManager = "bun";

      tools = {
        web.search.provider = "brave";

        media.audio = {
          enabled = true;
          scope = {
            default = "deny";
            rules = [
              {
                action = "allow";
                match = {
                  channel = "telegram";
                  chatType = "direct";
                };
              }
              {
                action = "allow";
                match = {
                  channel = "whatsapp";
                  chatType = "direct";
                };
              }
            ];
          };
          timeoutSeconds = 120;
          models = [
            {
              type = "cli";
              command = "/run/current-system/sw/bin/bash";
              args = [
                "-lc"
                ''/run/current-system/sw/bin/ffmpeg -y -i "{{MediaPath}}" -ar 16000 -ac 1 "{{OutputBase}}.wav" && /home/iva/.nix-profile/bin/whisper-cli -m /home/iva/.openclaw/models/whisper/ggml-large-v3.bin -otxt -of "{{OutputBase}}" -np -nt -l auto -t 8 "{{OutputBase}}.wav"''
              ];
            }
          ];
        };

        exec.pathPrepend = [
          "/etc/profiles/per-user/iva/bin"
          "/run/current-system/sw/bin"
        ];
      };
    };
  };

  systemd.user.services.openclaw-gateway.Service.EnvironmentFile = [
    "${config.home.homeDirectory}/.secrets/openclaw.env"
  ];

  home.file.".openclaw/openclaw.json".force = true;
  xdg.configFile."systemd/user/openclaw-gateway.service".force = true;

  xdg.desktopEntries."xp-pen-driver" = {
    name = "XP-Pen Tablet Driver";
    genericName = "Tablet Driver";
    comment = "Proprietary driver for XP-Pen Deco 01 V2";
    exec = "${scripts.xpPenLauncher}/bin/xp-pen-launcher";
    terminal = false;
    type = "Application";
    icon = "input-tablet";
    categories = ["Settings" "HardwareSettings"];
  };

  # Desktop specific GNOME settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      show-battery-percentage = true;
    };
    "org/gnome/desktop/peripherals/keyboard" = {
      numlock-state = false;
    };
    "org/gnome/desktop/peripherals/touchscreens/1a86:e2e3" = {
      output = ["JRP" "JRP7813S" "0"];
    };
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "nothing";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
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
      binding = "<Super>b";
      command = "toggle-night-light";
      name = "Toggle Night Light";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
      binding = "<Super>c";
      command = "${scripts.toggleConservation}/bin/toggle-conservation";
      name = "Toggle Battery Conservation";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
      binding = "<Super>space";
      command = "${scripts.toggleNerdDictation}/bin/toggle-nerd-dictation";
      name = "Toggle Nerd Dictation";
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
      switch-input-source = ["<Super>slash"];
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
      enabled-extensions = ["space-bar@luchrioh" "shaderpaper@fogyverse.in" "hibernate-status@dromi"];
      disable-user-extensions = false; # ensure it's not disabled
      disable-extension-version-validation = true;
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
    "org/gnome/mutter" = {
      dynamic-workspaces = true;
    };
    "org/gnome/desktop/input-sources" = {
      sources = [(pkgs.lib.gvariant.mkTuple ["xkb" "us"]) (pkgs.lib.gvariant.mkTuple ["xkb" "ru"]) (pkgs.lib.gvariant.mkTuple ["xkb" "ro+std"])];
      xkb-options = [];
    };
  };
}
