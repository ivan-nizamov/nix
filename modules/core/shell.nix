{ config, lib, pkgs, ... }:
let
  flakeTarget = config.local.rebuild.flakeTarget;
in
{
  options.local.rebuild.flakeTarget = lib.mkOption {
    type = lib.types.str;
    default = "thinkpad";
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
        # `m` is defined as a function below so it can resolve the current
        # Tailscale address dynamically instead of pinning one DNS/key path.
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
          local sudo_prompt
          shift

          sudo_prompt=$'\n[sudo] Password for %p: '

          printf '\n>>> NixOS rebuild needs sudo authentication.\n>>> Enter your password to continue.\n' >&2

          command sudo -v -p "$sudo_prompt" || return $?
          printf '>>> Authentication complete. Starting nixos-rebuild %s...\n' "$mode" >&2

          cores=$(_nixos_rebuild_cores)
          command sudo -n nixos-rebuild "$mode" --flake /home/iva/nix#${flakeTarget} --max-jobs 1 --cores "$cores" "$@"
        }

        nrt() {
          _nixos_rebuild_sudo test "$@"
        }

        m() {
          local target_ip

          if command -v tailscale >/dev/null 2>&1; then
            target_ip=$(tailscale ip -4 mainframe 2>/dev/null | head -n1)
          fi

          if [[ -n "$target_ip" ]]; then
            command ssh iva@"$target_ip" "$@"
          else
            command ssh mainframe-iva "$@"
          fi
        }

        unalias m 2>/dev/null || true

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
