{ config, lib, pkgs, ... }:
let
  flakeTarget = config.local.rebuild.flakeTarget;
in
{
  options.local.rebuild.flakeTarget = lib.mkOption {
    type = lib.types.str;
    default = "legion";
    description = "Flake target used by local rebuild helpers.";
  };

  config = {
    environment.systemPackages = with pkgs; [
      bat
      fastfetch
      gh
      git
      micro
      pkgs."nix-search-cli"
      pay-respects
      ripgrep
      starship
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
        m = "ssh -F /dev/null -i ~/.ssh/server_key iva@mainframe.tail506f5b.ts.net";
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
          command nixos-rebuild build --flake /home/iva/nix#${flakeTarget} --max-jobs 1 --cores "$cores" "$@"
        }

        _nixos_rebuild_sudo() {
          local mode=$1
          local cores
          shift

          cores=$(_nixos_rebuild_cores)
          command sudo nixos-rebuild "$mode" --flake /home/iva/nix#${flakeTarget} --max-jobs 1 --cores "$cores" "$@"
        }

        nrt() {
          _nixos_rebuild_sudo test "$@"
        }

        nrs() {
          _nixos_rebuild_sudo switch "$@"
        }
      '';
    };

    systemd.tmpfiles.rules = [
      "f /home/iva/.zshrc 0644 iva users - -"
    ];
  };
}
