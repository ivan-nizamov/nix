# NixOS Rebuild Commands

## Thinkpad Driftwm

Expected branch: `thinkpad-driftwm`.

```bash
cd /home/iva/nix && sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#thinkpad-driftwm
```

## Mainframe

Archival backup branch only. Not a deploy target.
