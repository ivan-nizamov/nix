#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_ROOT="/run/media/iva/nixos"
NEXTCLOUD_USER="iva"
TARGET_HOST="thinkpad"
FILES_DIR=""
SKIP_SWITCH=0
SKIP_SCAN=0

usage() {
  cat <<'EOF'
Usage: restore-nextcloud-local.sh [options]

Restore a Nextcloud instance from an attached NixOS root filesystem to this host.
If SOURCE_ROOT contains mainframe-backup-*/nextcloud-critical, the script restores
that tar/dump backup. Otherwise it falls back to a live /var/lib copy.

Options:
  --source-root PATH     Mounted backup root. Default: /run/media/iva/nixos
  --user USER            Nextcloud user id to restore/scan. Default: iva
  --files-dir PATH       Explicit source directory containing this user's files.
                         If omitted, the script searches for */USER/files.
  --host HOST            NixOS flake target to switch. Default: thinkpad
  --skip-switch          Copy data and fix ownership, but do not run nixos-rebuild.
  --skip-scan            Do not run nextcloud-occ files:scan after restore.
  -h, --help             Show this help.

Environment:
  MIN_FILE_BYTES         Minimum size for an auto-detected user files directory.
                         Default: 10485760 (10 MiB).
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-root)
      SOURCE_ROOT="${2:?missing value for --source-root}"
      shift 2
      ;;
    --user)
      NEXTCLOUD_USER="${2:?missing value for --user}"
      shift 2
      ;;
    --host)
      TARGET_HOST="${2:?missing value for --host}"
      shift 2
      ;;
    --files-dir)
      FILES_DIR="${2:?missing value for --files-dir}"
      shift 2
      ;;
    --skip-switch)
      SKIP_SWITCH=1
      shift
      ;;
    --skip-scan)
      SKIP_SCAN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "${EUID}" -ne 0 ]; then
  sudo_args=(
    "$0"
    --source-root "$SOURCE_ROOT"
    --user "$NEXTCLOUD_USER"
    --host "$TARGET_HOST"
  )
  if [ -n "$FILES_DIR" ]; then
    sudo_args+=(--files-dir "$FILES_DIR")
  fi
  if [ "$SKIP_SWITCH" -eq 1 ]; then
    sudo_args+=(--skip-switch)
  fi
  if [ "$SKIP_SCAN" -eq 1 ]; then
    sudo_args+=(--skip-scan)
  fi

  exec sudo \
    SOURCE_ROOT="$SOURCE_ROOT" \
    NEXTCLOUD_USER="$NEXTCLOUD_USER" \
    TARGET_HOST="$TARGET_HOST" \
    MIN_FILE_BYTES="${MIN_FILE_BYTES:-}" \
    "${sudo_args[@]}"
fi

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

dir_size_bytes() {
  du -sb "$1" 2>/dev/null | awk '{ print $1 }'
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_NEXTCLOUD="$SOURCE_ROOT/var/lib/nextcloud"
SOURCE_POSTGRES="$SOURCE_ROOT/var/lib/postgresql"
SOURCE_REDIS="$SOURCE_ROOT/var/lib/redis-nextcloud"
TARGET_SECRETS="/var/lib/nextcloud-secrets"
TARGET_NEXTCLOUD="/var/lib/nextcloud"
TARGET_POSTGRES="/var/lib/postgresql"
TARGET_REDIS="/var/lib/redis-nextcloud"
MIN_FILE_BYTES="${MIN_FILE_BYTES:-10485760}"

need awk
need du
need find
need rsync
need systemctl
need tar

[ -d "$SOURCE_ROOT" ] || die "Source root does not exist: $SOURCE_ROOT"
[ -d "$REPO_ROOT/.git" ] || die "Could not find repo root from script path: $REPO_ROOT"

critical_backup=""
while IFS= read -r candidate; do
  critical_backup="$candidate"
done < <(
  find "$SOURCE_ROOT" -xdev -path '*/nextcloud-critical' -type d -print 2>/dev/null | sort | tail -1
)

restore_mode="live"
if [ -n "$critical_backup" ] \
  && [ -f "$critical_backup/data/var-lib-nextcloud.tar" ] \
  && [ -f "$critical_backup/db/nextcloud-db.dump" ]; then
  restore_mode="critical"
fi

if [ "$restore_mode" = "critical" ]; then
  log "Using critical backup: $critical_backup"
  if [ -f "$critical_backup/SHA256SUMS" ]; then
    log "Verifying critical backup checksums"
    (cd "$critical_backup" && sha256sum -c SHA256SUMS)
  fi
  tar -tf "$critical_backup/data/var-lib-nextcloud.tar" "var/lib/nextcloud/data/${NEXTCLOUD_USER}/files/" >/dev/null \
    || die "Critical backup does not contain var/lib/nextcloud/data/${NEXTCLOUD_USER}/files/"
  best_files_size="$(tar -tvf "$critical_backup/data/var-lib-nextcloud.tar" "var/lib/nextcloud/data/${NEXTCLOUD_USER}/files/" 2>/dev/null | awk '{ sum += $3 } END { print sum + 0 }')"
else
  [ -d "$SOURCE_NEXTCLOUD" ] || die "No Nextcloud state at $SOURCE_NEXTCLOUD"
  [ -d "$SOURCE_POSTGRES" ] || die "No PostgreSQL state at $SOURCE_POSTGRES"

  log "Searching for a real Nextcloud files payload on $SOURCE_ROOT"
  if [ -n "$FILES_DIR" ]; then
    [ -d "$FILES_DIR" ] || die "Explicit --files-dir does not exist: $FILES_DIR"
    best_files_dir="$FILES_DIR"
    best_files_size="$(dir_size_bytes "$best_files_dir")"
  else
    mapfile -d '' file_candidates < <(
      find "$SOURCE_ROOT" -xdev -type d -path "*/${NEXTCLOUD_USER}/files" -print0 2>/dev/null
    )

    best_files_dir=""
    best_files_size=0
    for candidate in "${file_candidates[@]}"; do
      size="$(dir_size_bytes "$candidate")"
      if [ -n "$size" ] && [ "$size" -gt "$best_files_size" ]; then
        best_files_size="$size"
        best_files_dir="$candidate"
      fi
    done
  fi

  if [ -z "$best_files_dir" ] || { [ -z "$FILES_DIR" ] && [ "$best_files_size" -lt "$MIN_FILE_BYTES" ]; }; then
    log "Could not find a plausible ${NEXTCLOUD_USER}/files directory of at least ${MIN_FILE_BYTES} bytes."
    echo "Largest directories on the backup root:"
    du -xhd2 "$SOURCE_ROOT" 2>/dev/null | sort -h | tail -80
    die "Refusing to continue, because restoring without the file payload would keep files missing."
  fi

  log "Using file payload: $best_files_dir ($(du -sh "$best_files_dir" | awk '{ print $1 }'))"
fi

if [ "$best_files_size" -lt "$MIN_FILE_BYTES" ]; then
  die "Detected file payload is only ${best_files_size} bytes; refusing to restore an apparently empty file set."
fi

restore_database_dump() {
  local dump_path="$1"
  local dump_stage
  local staged_dump

  need pg_restore
  need psql
  need runuser

  log "Restoring PostgreSQL database from $dump_path"
  systemctl start postgresql.service
  dump_stage="$(mktemp -d)"
  staged_dump="$dump_stage/nextcloud-db.dump"
  cp "$dump_path" "$staged_dump"
  chown postgres:postgres "$staged_dump"
  chmod 0400 "$staged_dump"

  if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'nextcloud'" | grep -qx 1; then
    runuser -u postgres -- createuser nextcloud
  fi

  runuser -u postgres -- dropdb --if-exists nextcloud
  runuser -u postgres -- createdb -O nextcloud nextcloud
  if ! runuser -u postgres -- pg_restore --no-owner --role=nextcloud -d nextcloud "$staged_dump"; then
    rm -rf "$dump_stage"
    return 1
  fi
  rm -rf "$dump_stage"
}

extract_tar_state() {
  local archive="$1"
  local target="$2"
  local member="$3"
  local stage

  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' RETURN

  tar --acls --xattrs --numeric-owner -C "$stage" -xf "$archive" "$member"
  mkdir -p "$target"
  rsync -aAXH --numeric-ids --delete "$stage/$member/" "$target/"
  rm -rf "$stage"
  trap - RETURN
}

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="/var/lib/nextcloud-local-restore-backups/$timestamp"

log "Stopping local Nextcloud services"
systemctl stop \
  nextcloud-notify_push.service \
  nextcloud-whiteboard-config.service \
  nextcloud-whiteboard-server.service \
  nextcloud-office-config.service \
  nextcloud-setup.service \
  nextcloud-update-db.service \
  nextcloud-update-plugins.service \
  nextcloud-cron.service \
  phpfpm-nextcloud.service \
  nginx.service \
  redis-nextcloud.service \
  postgresql.service \
  coolwsd.service \
  2>/dev/null || true

log "Saving current local state under $backup_root"
mkdir -p "$backup_root"
for state_dir in "$TARGET_NEXTCLOUD" "$TARGET_POSTGRES" "$TARGET_REDIS" "$TARGET_SECRETS"; do
  if [ -e "$state_dir" ]; then
    backup_dest="$backup_root$state_dir"
    mkdir -p "$(dirname "$backup_dest")"
    rsync -aAXH --numeric-ids "$state_dir/" "$backup_dest/"
  fi
done

if [ "$restore_mode" = "critical" ]; then
  log "Extracting Nextcloud state from critical backup"
  extract_tar_state "$critical_backup/data/var-lib-nextcloud.tar" "$TARGET_NEXTCLOUD" "var/lib/nextcloud"

  if [ -f "$critical_backup/secrets/var-lib-nextcloud-secrets.tar" ]; then
    log "Extracting Nextcloud secrets"
    extract_tar_state "$critical_backup/secrets/var-lib-nextcloud-secrets.tar" "$TARGET_SECRETS" "var/lib/nextcloud-secrets"
  fi

  if [ -f "$critical_backup/state/var-lib-redis-nextcloud.tar" ]; then
    log "Extracting Redis state"
    extract_tar_state "$critical_backup/state/var-lib-redis-nextcloud.tar" "$TARGET_REDIS" "var/lib/redis-nextcloud"
  fi

  restore_database_dump "$critical_backup/db/nextcloud-db.dump"
else
  log "Copying Nextcloud app/config state"
  mkdir -p "$TARGET_NEXTCLOUD"
  rsync -aAXH --numeric-ids --delete "$SOURCE_NEXTCLOUD/" "$TARGET_NEXTCLOUD/"

  log "Copying PostgreSQL state"
  mkdir -p "$TARGET_POSTGRES"
  rsync -aAXH --numeric-ids --delete "$SOURCE_POSTGRES/" "$TARGET_POSTGRES/"

  if [ -d "$SOURCE_REDIS" ]; then
    log "Copying Redis state"
    mkdir -p "$TARGET_REDIS"
    rsync -aAXH --numeric-ids --delete "$SOURCE_REDIS/" "$TARGET_REDIS/"
  fi

  log "Copying user file payload into $TARGET_NEXTCLOUD/data/$NEXTCLOUD_USER/files"
  mkdir -p "$TARGET_NEXTCLOUD/data/$NEXTCLOUD_USER/files"
  rsync -aAXH --numeric-ids --delete "$best_files_dir/" "$TARGET_NEXTCLOUD/data/$NEXTCLOUD_USER/files/"
fi

log "Normalizing local ownership"
chown -R nextcloud:nextcloud "$TARGET_NEXTCLOUD"
if [ -d "$TARGET_REDIS" ]; then
  chown -R nextcloud:nextcloud "$TARGET_REDIS"
fi
chown -R postgres:postgres "$TARGET_POSTGRES"
if [ -d "$TARGET_SECRETS" ]; then
  chown -R root:root "$TARGET_SECRETS"
  chmod 0700 "$TARGET_SECRETS"
  find "$TARGET_SECRETS" -type f -exec chmod 0400 {} +
fi

if [ "$SKIP_SWITCH" -eq 0 ]; then
  log "Switching NixOS configuration .#$TARGET_HOST"
  nixos-rebuild switch --flake "$REPO_ROOT#$TARGET_HOST"
else
  log "Skipping nixos-rebuild switch"
fi

if [ "$SKIP_SCAN" -eq 0 ]; then
  log "Scanning restored files into Nextcloud"
  nextcloud-occ files:scan --path="/${NEXTCLOUD_USER}/files"
else
  log "Skipping Nextcloud file scan"
fi

log "Service status"
systemctl --failed --no-pager || true
curl -fsS http://localhost:8080/status.php || true
printf '\n'

log "Done. Local safety copy: $backup_root"
