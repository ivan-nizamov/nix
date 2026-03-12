{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.git
    pkgs.micro
    pkgs."nix-search-cli"
    pkgs.pay-respects
    pkgs.ripgrep
  ];

  programs.starship.enable = true;

  programs.zoxide = {
    enable = true;
    flags = [ "--cmd" "z" ];
  };

  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    shellAliases = {
      c = "codex --dangerously-bypass-approvals-and-sandbox";
      gad = "git add .";
      g = "gemini --yolo";
      gcm = "git commit -m";
      glog = "git log --all --decorate --oneline --graph";
      k = "kilocode";
      oc = "openclaw";
      oco = "opencode";
    };
    interactiveShellInit = ''
      mkdir -p "$HOME/.gemini"

      eval "$(${pkgs.pay-respects}/bin/pay-respects zsh --alias f)"

      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' group-name ""
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*:warnings' format '[no matches found]'

      _nixos_rebuild_cores() {
        local cpu_count target
        cpu_count=$(nproc --all)
        target=$(( cpu_count * 2 / 3 ))

        if (( target < 1 )); then
          target=1
        fi

        echo "$target"
      }

      nrb() {
        local cores
        cores=$(_nixos_rebuild_cores)
        command nixos-rebuild build --flake /home/iva/nix#mainframe --max-jobs 1 --cores "$cores" "$@"
      }

      nrt() {
        local cores
        cores=$(_nixos_rebuild_cores)
        sudo nixos-rebuild test --flake /home/iva/nix#mainframe --max-jobs 1 --cores "$cores" "$@"
      }

      nrs() {
        local cores
        cores=$(_nixos_rebuild_cores)
        sudo nixos-rebuild switch --flake /home/iva/nix#mainframe --max-jobs 1 --cores "$cores" "$@"
      }
    '';
  };
}
