# Nextcloud Porting Notes

These notes exist for future agents moving, unwrapping, or restoring the
Nextcloud instance from this flake. They are operational context only; they do
not affect the NixOS configuration.

## What Must Move

Do not migrate only `/var/lib/nextcloud`. A complete move needs:

- `/var/lib/nextcloud`
- `/var/lib/nextcloud-secrets`
- the PostgreSQL `nextcloud` database
- `/var/lib/redis-nextcloud` if preserving Redis state matters
- the NixOS Nextcloud module/config from this repository
- the correct external hostname and URL settings for the destination host

The local restore helper is `scripts/restore-nextcloud-local.sh`. It restores
the critical backup archives, database, secrets, Redis state, ownership, and
runs a Nextcloud file scan.

## Local vs Public Host Behavior

The Nextcloud module is host-aware:

- `mainframe` is treated as the public host and uses
  `mainframe.tail506f5b.ts.net`.
- non-mainframe hosts are treated as local restores and use
  `http://localhost:8080`.

Local restores intentionally remove SMTP credential settings from the restored
Nextcloud config. Otherwise restored mail settings can make NixOS-generated
systemd credentials fail on machines that do not have the mainframe secrets.

## Nextcloud Office / Collabora Details

Most restore issues came from Nextcloud Office WOPI URL mismatches, not from
the file payload itself.

Important local settings:

- browser/public URL: `http://localhost:8080`
- Collabora-to-Nextcloud callback URL: `http://127.0.0.1:8080`
- nginx listens on both `127.0.0.1:8080` and `[::1]:8080`
- the local `richdocuments` WOPI allowlist is deleted so restored mainframe
  allowlist state does not reject local callbacks

The IPv6 listener matters because Collabora can still generate or receive
`localhost:8080` URLs. If `localhost` resolves to `::1` while nginx only listens
on IPv4, document loading fails with Collabora `ECONNREFUSED` errors.

For a new public server, review all Collabora and richdocuments URL settings
instead of blindly keeping the local `localhost` or `127.0.0.1` values.

