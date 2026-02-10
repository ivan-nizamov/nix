{pkgs, ...}: let
  gogcli = pkgs.buildGoModule rec {
    pname = "gogcli";
    version = "0.9.0";
    src = pkgs.fetchFromGitHub {
      owner = "steipete";
      repo = "gogcli";
      rev = "v${version}";
      sha256 = "18ycgcax2hkfahlvadnhgk5k3agncqp262qcmsyg1rgz6zk70x0d";
    };
    vendorHash = "sha256-nig3GI7eM1XRtIoAh1qH+9PxPPGynl01dCZ2ppyhmzU=";
    go = pkgs.go_1_25;
  };
in {
  environment.systemPackages = with pkgs; [
    git
    gh
    stow
    emacs
    zed-editor
    codex
    starship
    zoxide
    tree
    bitwarden-desktop
    maple-mono.NF
    eb-garamond
    dconf-editor
    fastfetch
    obs-studio
    bat
    ripgrep
    fd
    gparted
    libsForQt5.xp-pen-deco-01-v2-driver
    ghostty
    gogcli
    nix-search-cli
    nixd
    nixpkgs-fmt
    vscode-langservers-extracted
    rnote
    anki-bin
    mpv
    apple-cursor
    gnome-tweaks
    gnomeExtensions.space-bar
    nodejs_22
    zoom-us
  ];
}
