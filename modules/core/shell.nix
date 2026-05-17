{ config, lib, pkgs, ... }:
let
  flakeTarget = config.local.rebuild.flakeTarget;
  isThinkPad = config.networking.hostName == "thinkpad";
  setupThinkPadMainframeSshKey = pkgs.writeShellScriptBin "setup-thinkpad-mainframe-ssh-key" ''
    set -euo pipefail

    ssh_dir="$HOME/.ssh"
    key_file="$ssh_dir/thinkpad_to_mainframe"
    pub_file="$ssh_dir/thinkpad_to_mainframe.pub"
    cfg_file="$ssh_dir/config"
    managed_begin="# >>> ThinkPad -> Mainframe managed by setup-thinkpad-mainframe-ssh-key >>>"
    managed_end="# <<< ThinkPad -> Mainframe managed by setup-thinkpad-mainframe-ssh-key <<<"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    tmp_private=$(mktemp "$ssh_dir/server_key.tmp.XXXXXX")
    tmp_public=$(mktemp "$ssh_dir/server_key.pub.tmp.XXXXXX")
    trap 'rm -f "$tmp_private" "$tmp_public"' EXIT

    cat <<'EOF'
Paste the private key for ThinkPad -> Mainframe.
Finish with Ctrl-D on a new line.
EOF
    cat > "$tmp_private"

    if ! grep -q "BEGIN OPENSSH PRIVATE KEY" "$tmp_private"; then
      echo "Invalid private key format: expected OPENSSH private key block." >&2
      exit 1
    fi

    cat <<'EOF'
Paste the public key for ThinkPad -> Mainframe.
Finish with Ctrl-D on a new line.
EOF
    cat > "$tmp_public"

    pub_type=$(awk 'NR==1 { print $1 }' "$tmp_public")
    pub_blob=$(awk 'NR==1 { print $2 }' "$tmp_public")
    if [ -z "$pub_type" ] || [ -z "$pub_blob" ]; then
      echo "Invalid public key format: expected 'ssh-... BASE64 [comment]'." >&2
      exit 1
    fi

    derived_pub=$(${pkgs.openssh}/bin/ssh-keygen -y -f "$tmp_private")
    derived_blob=$(printf '%s\n' "$derived_pub" | awk '{ print $2 }')
    if [ "$derived_blob" != "$pub_blob" ]; then
      echo "Private/public key mismatch. Nothing was written." >&2
      exit 1
    fi

    install -m 600 "$tmp_private" "$key_file"
    install -m 644 "$tmp_public" "$pub_file"

    if [ -f "$cfg_file" ]; then
      awk -v begin="$managed_begin" -v end="$managed_end" '
        $0 == begin { skip = 1; next }
        $0 == end   { skip = 0; next }
        skip != 1 { print }
      ' "$cfg_file" > "$cfg_file.tmp"
      mv "$cfg_file.tmp" "$cfg_file"
    fi

    cat >> "$cfg_file" <<EOF
$managed_begin
Host Mainframe
  HostName mainframe.tail506f5b.ts.net
  User iva
  IdentityFile ~/.ssh/thinkpad_to_mainframe
  IdentitiesOnly yes
Host mainframe-iva
  HostName mainframe.tail506f5b.ts.net
  User iva
  IdentityFile ~/.ssh/thinkpad_to_mainframe
  IdentitiesOnly yes
$managed_end
EOF
    chmod 600 "$cfg_file"

    rm -f "$tmp_private" "$tmp_public"
    trap - EXIT

    echo "Saved:"
    echo "  $key_file"
    echo "  $pub_file"
    echo "Updated:"
    echo "  $cfg_file (Host Mainframe + mainframe-iva)"
    echo
    echo "Test with: m 'hostname; whoami'"
  '';
in
{
  options.local.rebuild.flakeTarget = lib.mkOption {
    type = lib.types.str;
    default = "thinkpad";
    description = "Flake target used by local rebuild helpers.";
  };

  config = {
    environment.systemPackages = with pkgs; [
      bat
      fastfetch
      gh
      git
      micro
      pkgs."nix-search-cli"
      pay-respects
      ripgrep
      starship
      wl-clipboard
    ] ++ lib.optionals isThinkPad [ setupThinkPadMainframeSshKey ];

    programs.starship.enable = true;

    programs.zoxide = {
      enable = true;
      flags = [ "--cmd" "z" ];
    };

    programs.zsh = {
      enable = true;
      enableBashCompletion = true;
      shellAliases = {
        c = "codex --dangerously-bypass-approvals-and-sandbox";
        gad = "git add .";
        g = "gemini --yolo";
        gcm = "git commit -m";
        glog = "git log --all --decorate --oneline --graph";
        k = "kilocode";
      } // lib.optionalAttrs isThinkPad {
        tmkey = "setup-thinkpad-mainframe-ssh-key";
        mkey = "setup-thinkpad-mainframe-ssh-key";
      } // {
        # `m` is defined as a function below so it can resolve the current
        # Tailscale address dynamically instead of pinning one DNS/key path.
        oc = "openclaw";
        oco = "opencode";
      };
      interactiveShellInit = ''
        mkdir -p "$HOME/.gemini"

        eval "$(${pkgs.pay-respects}/bin/pay-respects zsh --alias f)"

        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' group-name ""
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*:warnings' format '[no matches found]'

        _nixos_rebuild_cores() {
          local cpu_count target
          cpu_count=$(nproc --all)
          target=$(( cpu_count * 2 / 3 ))

          if (( target < 1 )); then
            target=1
          fi

          echo "$target"
        }

        nrb() {
          local cores
          cores=$(_nixos_rebuild_cores)
          command nixos-rebuild build --flake /home/iva/nix#${flakeTarget} --max-jobs 1 --cores "$cores" "$@"
        }

        _nixos_rebuild_sudo() {
          local mode=$1
          local cores
          shift

          cores=$(_nixos_rebuild_cores)
          command sudo nixos-rebuild "$mode" --flake /home/iva/nix#${flakeTarget} --max-jobs 1 --cores "$cores" "$@"
        }

        nrt() {
          _nixos_rebuild_sudo test "$@"
        }

        m() {
          local target_ip

          if command -v tailscale >/dev/null 2>&1; then
            target_ip=$(tailscale ip -4 mainframe 2>/dev/null | head -n1)
          fi

          if [[ -n "$target_ip" ]]; then
            command ssh -F /dev/null -i ~/.ssh/thinkpad_to_mainframe iva@"$target_ip" "$@"
          else
            command ssh Mainframe "$@"
          fi
        }

        a53() {
          local target_ip

          if command -v tailscale >/dev/null 2>&1; then
            target_ip=$(tailscale ip -4 a53 2>/dev/null | head -n1)
          fi

          if [[ -z "$target_ip" ]]; then
            target_ip=100.95.99.98
          fi

          command ssh -p 8022 -F /dev/null -i ~/.ssh/thinkpad_to_a53 u0_a424@"$target_ip" "$@"
        }

        unalias m 2>/dev/null || true
        unalias a53 2>/dev/null || true

        nrs() {
          _nixos_rebuild_sudo switch "$@"
        }
      '';
    };

    systemd.tmpfiles.rules = [
      "f /home/iva/.zshrc 0644 iva users - -"
    ];
  };
}
