{ ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      c = "codex --dangerously-bypass-approvals-and-sandbox";
      nrb = "nixos-rebuild build --flake /home/iva/nix#mainframe --max-jobs 1 --cores 6";
      nrt = "nixos-rebuild test --flake /home/iva/nix#mainframe --max-jobs 1 --cores 6";
      nrs = "nixos-rebuild switch --flake /home/iva/nix#mainframe --max-jobs 1 --cores 6";
    };
  };
}
