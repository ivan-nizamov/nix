# Host Branches

This repository keeps deployable NixOS configurations in one branch per host:

- `mainframe` is an archival backup branch, not a deploy target.
- `thinkpad-driftwm` deploys `.#thinkpad-driftwm`.
- `legion` deploys `.#legion`.

Use the host branch as the source of truth for that machine:

```bash
git switch thinkpad-driftwm
sudo nixos-rebuild switch --flake .#thinkpad-driftwm

git switch legion
sudo nixos-rebuild switch --flake .#legion
```

Shared modules still live in the same tree. When a shared change should apply to
more than one machine, commit it on the first affected host branch, switch that
host, then merge or cherry-pick the same commit to the other affected host
branches and switch those hosts too.

`main` is no longer the deployment branch for every machine. Treat it as legacy
history or an integration branch, not as the branch a host should blindly pull
before rebuilding.
