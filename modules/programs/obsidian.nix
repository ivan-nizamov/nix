{ inputs, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  baseObsidian = unstablePkgs.obsidian;
  updatePattern = "obsidian*.asar*";
  obsidian = pkgs.symlinkJoin {
    name = "obsidian";
    paths = [ baseObsidian ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/obsidian"
      makeWrapper ${lib.getExe baseObsidian} "$out/bin/obsidian" \
        --run '
          config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/obsidian"
          quarantine_dir="$config_dir/disabled-updates"

          # Keep Obsidian on the integrated GPU. This avoids Electron/Wayland
          # startup problems caused by inheriting PRIME offload variables from
          # the shell session.
          unset __NV_PRIME_RENDER_OFFLOAD
          unset __NV_PRIME_RENDER_OFFLOAD_PROVIDER
          unset __GLX_VENDOR_LIBRARY_NAME
          unset __VK_LAYER_NV_optimus

          if [ -d "$config_dir" ]; then
            mkdir -p "$quarantine_dir"

            # The Nix package owns the app bundle. Remove any self-downloaded
            # .asar update so launches always use the packaged version.
            for update in "$config_dir"/${updatePattern} "$quarantine_dir"/${updatePattern}; do
              [ -e "$update" ] || continue
              rm -f "$update"
            done
          fi
        '
    '';
  };
  vaultPath = "/home/iva/Sync";
  vaultName = builtins.baseNameOf vaultPath;
  obsidianVault = pkgs.writeShellApplication {
    name = "obsidian-vault";
    runtimeInputs = [ obsidian ];
    text = ''
      cd ${lib.escapeShellArg vaultPath}
      exec obsidian "$@"
    '';
  };
in
{
  environment.variables = {
    OBSIDIAN_VAULT_DIR = vaultPath;
    OBSIDIAN_VAULT_NAME = vaultName;
  };

  environment.systemPackages = [
    obsidian
    obsidianVault
  ];

  programs.zsh.shellAliases = {
    ob = "obsidian-vault";
  };

  programs.zsh.interactiveShellInit = lib.mkAfter ''
    ov() {
      cd ${lib.escapeShellArg vaultPath} || return 1
    }
  '';

  system.activationScripts.obsidianCli = {
    text = ''
      config_dir=/home/iva/.config/obsidian
      config_file="$config_dir/obsidian.json"
      quarantine_dir="$config_dir/disabled-updates"
      default_vault=${lib.escapeShellArg vaultPath}
      tmp_file="$(mktemp)"
      next_tmp_file="$(mktemp)"
      default_vault_id="$(${pkgs.coreutils}/bin/printf '%s' "$default_vault" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-16)"

      if [ ! -d "$config_dir" ]; then
        install -d -o iva -g users -m 700 "$config_dir"
      fi

      if [ ! -d "$quarantine_dir" ]; then
        install -d -o iva -g users -m 700 "$quarantine_dir"
      fi

      for update in "$config_dir"/${updatePattern} "$quarantine_dir"/${updatePattern}; do
        if [ -e "$update" ]; then
          rm -f "$update"
        fi
      done

      for cache_dir in \
        "$config_dir/Cache" \
        "$config_dir/Code Cache" \
        "$config_dir/GPUCache" \
        "$config_dir/DawnGraphiteCache" \
        "$config_dir/DawnWebGPUCache"
      do
        rm -rf "$cache_dir"
      done

      if [ -s "$config_file" ] && ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
        ${pkgs.jq}/bin/jq '. + {cli: true}' "$config_file" > "$tmp_file"
      else
        printf '%s\n' '{"cli":true}' > "$tmp_file"
      fi

      current_open_vault="$(${pkgs.jq}/bin/jq -r '
        (.vaults // {})
        | to_entries[]
        | select(.value.open == true)
        | .value.path
      ' "$tmp_file" 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)"

      repair_open_vault=0
      if [ -d "$default_vault/.obsidian" ]; then
        if [ -z "$current_open_vault" ] || [ ! -d "$current_open_vault" ]; then
          repair_open_vault=1
        elif find "$current_open_vault" -mindepth 2 -type d -name .obsidian -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
          repair_open_vault=1
        fi
      fi

      if [ "$repair_open_vault" -eq 1 ]; then
        ${pkgs.jq}/bin/jq \
          --arg id "$default_vault_id" \
          --arg path "$default_vault" \
          --argjson ts "$(${pkgs.coreutils}/bin/date +%s%3N)" \
          '
            .vaults = (
              (.vaults // {})
              | with_entries(.value = ((.value // {}) + { open: false }))
              | . + {
                ($id): ((.[$id] // {}) + {
                  path: $path,
                  ts: $ts,
                  open: true
                })
              }
            )
          ' "$tmp_file" > "$next_tmp_file"
        mv "$next_tmp_file" "$tmp_file"
      fi

      install -o iva -g users -m 600 "$tmp_file" "$config_file"
      rm -f "$tmp_file" "$next_tmp_file"
    '';
  };
}
