# NixOS Rebuild Commands

## Legion

Expected branch: `legion`.

```bash
cd /home/iva/nix && sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#legion
```
