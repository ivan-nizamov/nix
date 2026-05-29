# NixOS Rebuild Commands

## Thinkpad

Expected branch: `thinkpad`.

```bash
cd /home/iva/nix && sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#thinkpad
```

## Mainframe

Expected branch: `mainframe`.

```bash
ssh -t mainframe-iva 'zsh -ic "cd /home/iva/nix && sudo NIX_CONFIG=\"experimental-features = nix-command flakes\" nixos-rebuild switch --flake .#mainframe"'
```
