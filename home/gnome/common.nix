{
  config,
  pkgs,
  lib,
  ...
}: let
  scripts = import ../../modules/home/scripts.nix {inherit pkgs;};
  spaceBarStyles = ".space-bar {\\n  -natural-hpadding: 12px;\\n}\\n\\n.space-bar-workspace-label.active {\\n  margin: 0 4px;\\n  background-color: rgba(255,255,255,0.3);\\n  color: rgba(255,255,255,1);\\n  border-color: rgba(0,0,0,0);\\n  font-weight: 700;\\n  border-radius: 4px;\\n  border-width: 0px;\\n  padding: 3px 8px;\\n}\\n\\n.space-bar-workspace-label.inactive {\\n  margin: 0 4px;\\n  background-color: rgba(0,0,0,0);\\n  color: rgba(255,255,255,1);\\n  border-color: rgba(0,0,0,0);\\n  font-weight: 700;\\n  border-radius: 4px;\\n  border-width: 0px;\\n  padding: 3px 8px;\\n}\\n\\n.space-bar-workspace-label.inactive.empty {\\n  margin: 0 4px;\\n  background-color: rgba(0,0,0,0);\n  color: rgba(255,255,255,0.5);\n  border-color: rgba(0,0,0,0);\n  font-weight: 700;\n  border-radius: 4px;\n  border-width: 0px;\n  padding: 3px 8px;\n}";

  repoRoot =
    if config._module.args ? repoRoot
    then config._module.args.repoRoot
    else null;
  resolvedRepoRoot =
    if repoRoot != null
    then repoRoot
    else "${config.home.homeDirectory}/nix";
  repoRootPath = toString resolvedRepoRoot;

  emacsInitOrg = "${repoRootPath}/dotfiles/emacs/.emacs.d/init.org";
  emacsInitEl = "${repoRootPath}/dotfiles/emacs/.emacs.d/init.el";
  emacsTarget = "$HOME/.emacs.d/init.el";
  emacsDir = "${repoRootPath}/dotfiles/emacs/.emacs.d";
  emacsExec = "${pkgs.emacs}/bin/emacs";

  emacsTangle = ''
    set -euo pipefail

    tmp_out="$(${pkgs.coreutils}/bin/mktemp /tmp/emacs-init.XXXXXX)"

    export PATH="${pkgs.git}/bin:${pkgs.coreutils}/bin:$PATH"
    mkdir -p "$HOME/.emacs.d"

    ${emacsExec} --batch -Q \
      --directory ${emacsDir} \
      -l org \
      --eval '(setq org-confirm-babel-evaluate nil)' \
      --visit "${emacsInitOrg}" \
      --funcall org-babel-tangle

    if [ "${emacsInitEl}" -ef "${emacsTarget}" ]; then
      cp "${emacsInitEl}" "$tmp_out"
      install -m 0644 "$tmp_out" "${emacsTarget}"
    else
      install -m 0644 "${emacsInitEl}" "${emacsTarget}"
    fi

    rm -f "$tmp_out"
  '';
in {
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
    emacs
    scripts.toggleNightLight
  ];

  home.activation.emacsTangleInit = lib.hm.dag.entryAfter ["writeBoundary"] emacsTangle;

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
      two-finger-scrolling-enabled = true;
    };
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-temperature = pkgs.lib.gvariant.mkUint32 1000;
      night-light-schedule-automatic = false;
      night-light-schedule-from = 0.0;
      night-light-schedule-to = 24.0;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    "org/gnome/desktop/session" = {
      idle-delay = 0;
    };
    "org/gnome/shell/extensions/space-bar/appearance" = {
      application-styles = spaceBarStyles;
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
  };
}
