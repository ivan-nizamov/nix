{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.git
    pkgs.pay-respects
    pkgs.ripgrep
  ];

  programs.zoxide = {
    enable = true;
    flags = [ "--cmd" "z" ];
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      c = "codex --dangerously-bypass-approvals-and-sandbox";
      g = "gemini --yolo";
      k = "kilocode";
      oc = "openclaw";
      oco = "opencode";
    };
    interactiveShellInit = ''
      mkdir -p "$HOME/.gemini"

      eval "$(${pkgs.pay-respects}/bin/pay-respects zsh --alias f)"

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
