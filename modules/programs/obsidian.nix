{ inputs, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  vaultPath = "/home/iva/Sync/Main Vault";
  vaultName = builtins.baseNameOf vaultPath;
  obsidianVault = pkgs.writeShellApplication {
    name = "obsidian-vault";
    runtimeInputs = [ unstablePkgs.obsidian ];
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
    unstablePkgs.obsidian
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
      tmp_file="$(mktemp)"

      if [ ! -d "$config_dir" ]; then
        install -d -o iva -g users -m 700 "$config_dir"
      fi

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
