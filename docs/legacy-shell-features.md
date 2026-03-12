# Legacy Shell Features To Consider

These features exist in the legacy Zsh config and can be ported into the NixOS shell module if you want them back.

## Ready To Port

- `starship` prompt initialization via `eval "$(starship init zsh)"`
- Git shortcuts:
  - `gad='git add .'`
  - `gcm='git commit -m'`
  - `glog='git log --all --decorate --oneline --graph'`
- User npm bin path export: `export PATH="$HOME/.npm-global/bin:$PATH"`
- VoxType helper functions:
  - `vr` to restart `voxtype.service`
  - `vs` to report `voxtype.service` status and memory usage

## Probably Not Worth Porting As-Is

- `zc='zeroclaw'`
  - The current system uses `openclaw`, so this alias looks obsolete unless you still want a compatibility alias.
- Hostname-derived rebuild aliases:
  - Legacy config used `.#$(hostname -s)`.
  - Current config already has `nrb`, `nrt`, and `nrs` pinned to `.#mainframe` with CPU-aware defaults, which is safer for this repo.
