{ inputs, pkgs, ... }:
let
  spaceBarStyles = ''
    .space-bar {
      -natural-hpadding: 12px;
    }

    .space-bar-workspace-label.active {
      margin: 0 4px;
      background-color: rgba(255,255,255,0.3);
      color: rgba(255,255,255,1);
      border-color: rgba(0,0,0,0);
      font-weight: 700;
      border-radius: 4px;
      border-width: 0px;
      padding: 3px 8px;
    }

    .space-bar-workspace-label.inactive {
      margin: 0 4px;
      background-color: rgba(0,0,0,0);
      color: rgba(255,255,255,1);
      border-color: rgba(0,0,0,0);
      font-weight: 700;
      border-radius: 4px;
      border-width: 0px;
      padding: 3px 8px;
    }

    .space-bar-workspace-label.inactive.empty {
      margin: 0 4px;
      background-color: rgba(0,0,0,0);
      color: rgba(255,255,255,0.5);
      border-color: rgba(0,0,0,0);
      font-weight: 700;
      border-radius: 4px;
      border-width: 0px;
      padding: 3px 8px;
    }
  '';
  telegramDesktop = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.telegram-desktop;
  zedEditor = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor;
  zenBrowser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
in
{
  programs.dconf.enable = true;

  environment.systemPackages = [
    pkgs.gnomeExtensions.space-bar
    telegramDesktop
    zedEditor
    zenBrowser
  ];

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          enabled-extensions = [ "space-bar@luchrioh" ];
          disable-user-extensions = false;
          disable-extension-version-validation = true;
        };
        "org/gnome/desktop/peripherals/mouse" = {
          accel-profile = "flat";
          natural-scroll = true;
          speed = -0.176;
        };
        "org/gnome/desktop/peripherals/touchpad" = {
          two-finger-scrolling-enabled = true;
        };
        "org/gnome/shell/extensions/space-bar/appearance" = {
          application-styles = spaceBarStyles;
          active-workspace-font-weight = "700";
          inactive-workspace-font-weight = "700";
          empty-workspace-font-weight = "700";
        };
        "org/gnome/shell/extensions/space-bar/behavior" = {
          always-show-numbers = false;
          smart-workspace-names = false;
          indicator-style = "workspaces-bar";
          position = "left";
          scroll-wheel = "panel";
          toggle-overview = false;
        };
        "org/gnome/shell/extensions/space-bar/shortcuts" = {
          enable-move-to-workspace-shortcuts = true;
          enable-activate-workspace-shortcuts = true;
          activate-empty-key = [ "<Super>j" ];
          back-and-forth = false;
        };
      };
    }
  ];

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
