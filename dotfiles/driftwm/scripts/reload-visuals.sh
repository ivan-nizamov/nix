#!/usr/bin/env sh

set -eu

# Touch the compositor config so driftwm's built-in watcher reloads it,
# then restart Waybar so bar layout/style changes are visible immediately.
touch "$HOME/.config/driftwm/config.toml"
systemctl --user restart waybar.service || pkill -SIGUSR2 waybar || true
