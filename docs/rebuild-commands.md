# NixOS Rebuild Commands

## Thinkpad

```bash
cd /home/iva/nix && sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#thinkpad
```

## Mainframe

```bash
ssh -t mainframe-iva 'zsh -ic "cd /home/iva/nix && sudo NIX_CONFIG=\"experimental-features = nix-command flakes\" nixos-rebuild switch --flake .#mainframe"'
```