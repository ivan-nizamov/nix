{ pkgs, ... }:
let
  reportScript = pkgs.writeShellScript "service-failure-report" ''
    set -eu

    unit="$1"
    report_dir="/var/lib/service-failure-reports"
    report_file="$report_dir/$unit.md"
    timestamp="$(${pkgs.coreutils}/bin/date --iso-8601=seconds)"

    ${pkgs.coreutils}/bin/mkdir -p "$report_dir"

    {
      echo "# Service failure report"
      echo
      echo "- Unit: \`$unit\`"
      echo "- Timestamp: \`$timestamp\`"
      echo
      echo "## systemctl status"
      echo
      echo '```text'
      ${pkgs.systemd}/bin/systemctl status "$unit" --no-pager || true
      echo '```'
      echo
      echo "## Recent journal"
      echo
      echo '```text'
      ${pkgs.systemd}/bin/journalctl -u "$unit" -n 200 --no-pager || true
      echo '```'
      echo
    } >> "$report_file"
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/service-failure-reports 0755 root root -"
  ];

  systemd.services."service-failure-report@" = {
    description = "Write a markdown report for %I service failures";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reportScript} %i";
    };
  };
}
