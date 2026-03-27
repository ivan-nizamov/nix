{ inputs, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  baseObsidian = unstablePkgs.obsidian;
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

          if [ -d "$config_dir" ]; then
            mkdir -p "$quarantine_dir"

            # The Nix package should own the app bundle. Quarantine any
            # self-downloaded .asar update so launches keep using the packaged
            # version instead of a mismatched bundle from ~/.config/obsidian.
            for update in "$config_dir"/obsidian-*.asar; do
              [ -e "$update" ] || continue
              mv -f "$update" "$quarantine_dir/$(basename "$update")"
            done
          fi
        '
    '';
  };
  vaultPath = "/home/iva/Sync/Main Vault";
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
      tmp_file="$(mktemp)"

      if [ ! -d "$config_dir" ]; then
        install -d -o iva -g users -m 700 "$config_dir"
      fi

      if [ ! -d "$quarantine_dir" ]; then
        install -d -o iva -g users -m 700 "$quarantine_dir"
      fi

      for update in "$config_dir"/obsidian-*.asar; do
        if [ -e "$update" ]; then
          mv "$update" "$quarantine_dir/$(basename "$update")"
        fi
      done

      if [ -s "$config_file" ]; then
        if ! ${pkgs.jq}/bin/jq '. + {cli: true}' "$config_file" > "$tmp_file"; then
          printf '%s\n' '{"cli":true}' > "$tmp_file"
        fi
      else
        printf '%s\n' '{"cli":true}' > "$tmp_file"
      fi

      install -o iva -g users -m 600 "$tmp_file" "$config_file"
      rm -f "$tmp_file"
    '';
  };
}
