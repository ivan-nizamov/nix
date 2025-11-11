# Repository Guidelines

## Project Structure & Module Organization
The root `flake.nix` defines all inputs and exports `nixosConfigurations` plus `homeConfigurations`. Host-specific logic lives under `hosts/<name>/`; `hosts/laptop/configuration.nix` imports its paired hardware profile and should remain the single entrypoint per device. Dotfiles intended for stow live in `dotfiles/<tool>/`, mirroring their final locations (for example `dotfiles/vscode/.config/Code/User/settings.json`). Keep host assets, secrets, and machine notes inside `hosts/<name>/` to avoid leaking them into other builds.

## Build, Test & Development Commands
- `nix flake check` – lints the flake, evaluates each configuration, and prevents attribute regressions.
- `nixos-rebuild --flake .#laptop test` – builds and activates the laptop system configuration without touching the bootloader.
- `nixos-rebuild --flake .#laptop switch` – performs a full rebuild, activation, and bootloader update.
- `nix run .#homeConfigurations.dotfiles.activate` – dry-runs the dotfiles home-manager activation for validation before deploying.

## Coding Style & Naming Conventions
Use two-space indentation in all Nix files, mirroring the existing hosts configuration. Attribute sets should sort higher-level keys logically (boot, networking, services, users) and keep trailing semicolons on their own lines. Favor descriptive option names (`services.pipewire`, `environment.systemPackages`) and snake-case identifiers for new variables. Run `nix fmt` (Alejandra-compatible) before committing to normalize spacing and align braces.

## Testing Guidelines
Every change must pass `nix flake check` locally; add targeted `nixosTests` blocks if new modules introduce critical behavior. For risky service changes, run `nixos-rebuild ... test` on a VM or spare profile before touching real hardware. Name new tests after the host or module they cover (`tests.laptop-usb`) and document assumptions inside the test derivation.

## Commit & Pull Request Guidelines
Follow the imperative, sentence-style messages already in history (e.g., “Implement correct zsh configuration”). Group related edits into a single commit and mention the affected host or module in the subject. Pull requests should include: summary of motivation, key commands executed (`nix flake check`, `nixos-rebuild test`), screenshots or logs for UI-facing changes, and references to tracked issues or TODO items. Call out any manual migration steps so other agents can reproduce the rollout safely.
