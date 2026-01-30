# Improvements Tracker

This tracks suggested changes to move the repo closer to a dendritic
configuration style (smaller reusable modules with thin host leafs),
plus quality-of-life and best-practice tweaks.

## Todo

- [ ] Extract shared system config into `modules/system/common.nix`.
- [ ] Split Home Manager into common GNOME + host overrides.
- [ ] Centralize package lists.
- [ ] Move custom scripts into a shared module.
- [ ] Remove hard-coded repo paths in activation scripts.
- [ ] Import `nixos-hardware` modules where applicable.
- [ ] Add Nix maintenance defaults (`nix.gc`, `nix.optimise`).
- [ ] Add `.gitignore` for `result` and `result-*`.

## Structure / Modularity

- Extract shared system config into a common module.
  - Create `modules/system/common.nix` for shared options:
    nix settings, i18n, time, pipewire, printing, fonts, base packages,
    users, zsh, nix-ld.
  - Keep `hosts/*/configuration.nix` minimal: hardware, host-only options,
    and host-specific packages.
- Split Home Manager into common GNOME + host overrides.
  - Create `home/gnome/common.nix` with shared dconf and packages.
  - Keep only deltas in `hosts/*/gnome.nix`.
  - Use `lib.mkMerge` / `lib.mkDefault` for clean overrides.

## Packages / Scripts

- Centralize package lists.
  - Move shared packages into `modules/packages.nix` (or similar).
  - Keep host-only packages in host files.
- Move custom scripts into a single module.
  - Create `modules/home/scripts.nix` or `pkgs/` and expose via
    `pkgs.writeShellApplication` to declare runtime deps.

## Portability / Inputs

- Avoid hard-coded repo paths in activation scripts.
  - Pass a `repoRoot` via `specialArgs` or build paths from
    `config.home.homeDirectory`.
- Use `nixos-hardware` modules where applicable.
  - Import hardware modules for laptop/mainframe if available to reduce
    manual kernel params and power tweaks.

## QoL / Best Practices

- Add Nix maintenance defaults in the shared system module.
  - `nix.gc.automatic = true`
  - `nix.optimise.automatic = true`
- Add a `.gitignore` for `result` and `result-*` outputs.
