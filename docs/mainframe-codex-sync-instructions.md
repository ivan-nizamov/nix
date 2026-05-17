# Mainframe Codex: ThinkPad -> Mainframe Sync

Run these commands on `mainframe`:

```bash
set -euo pipefail

cd /home/iva/nix
git fetch --all --prune
git checkout main
git pull --ff-only

git log --oneline -n 20
git show --name-status --oneline 6bbe4ec || true
git show --name-status --oneline dee69a9 || true

mainframe-rebuild switch

rg -n "users\\.users\\.iva\\.openssh\\.authorizedKeys\\.keys|ssh-rsa|thinkpad_to_mainframe" hosts/mainframe/default.nix modules/core/shell.nix
```

Expected result:
- `main` includes commits `6bbe4ec` and `dee69a9`.
- `mainframe-rebuild switch` exits successfully.
- `hosts/mainframe/default.nix` contains the ThinkPad public key in `authorizedKeys`.
