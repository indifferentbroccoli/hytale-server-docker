#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/hytale/server/functions.sh"

LogAction "Set file permissions"

if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
    LogWarn "PUID and PGID not set. Using default values (1000)."
    PUID=1000
    PGID=1000
fi
   
usermod -o -u "${PUID}" hytale
groupmod -o -g "${PGID}" hytale
chown -R ${PUID}:${PGID} /home/hytale/server-files /home/hytale/

cat /branding

# Set up persistent machine-id for encrypted auth
SERVER_FILES="/home/hytale/server-files"
MACHINE_ID_DIR="$SERVER_FILES/.machine-id"
mkdir -p "$MACHINE_ID_DIR"

if [ ! -f "$MACHINE_ID_DIR/uuid" ]; then
    LogInfo "Generating persistent machine-id for encrypted auth..."
    MACHINE_UUID=$(cat /proc/sys/kernel/random/uuid)
    MACHINE_UUID_NO_DASH=$(echo "$MACHINE_UUID" | tr -d '-' | tr '[:upper:]' '[:lower:]')
    
    echo "$MACHINE_UUID_NO_DASH" > "$MACHINE_ID_DIR/machine-id"
    echo "$MACHINE_UUID_NO_DASH" > "$MACHINE_ID_DIR/dbus-machine-id"
    echo "$MACHINE_UUID" > "$MACHINE_ID_DIR/product_uuid"
    echo "$MACHINE_UUID" > "$MACHINE_ID_DIR/uuid"
    
    chown -R ${PUID}:${PGID} "$MACHINE_ID_DIR"
fi

# Copy to system locations
cp "$MACHINE_ID_DIR/machine-id" /etc/machine-id
mkdir -p /var/lib/dbus
cp "$MACHINE_ID_DIR/dbus-machine-id" /var/lib/dbus/machine-id

LogInfo "Machine ID configured for encrypted auth persistence"

if [ "${DOWNLOAD_ON_START:-true}" = "true" ]; then
    download_server
else
    LogWarn "DOWNLOAD_ON_START is set to false, skipping server download"
fi

# shellcheck disable=SC2317
term_handler() {
    if ! shutdown_server; then
        # Force shutdown if graceful shutdown fails
        kill -SIGTERM "$(pgrep -f HytaleServer.jar)"
    fi
    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

export DEFAULT_PORT
export SERVER_NAME
export MAX_PLAYERS
export VIEW_DISTANCE
export ENABLE_BACKUPS
export BACKUP_FREQUENCY
export BACKUP_MAX_COUNT
export BACKUP_DIR
export DISABLE_SENTRY
export USE_AOT_CACHE
export AUTH_MODE
export ACCEPT_EARLY_PLUGINS
export MIN_MEMORY
export MAX_MEMORY
export JVM_ARGS
export PATCHLINE
export SESSION_TOKEN
export IDENTITY_TOKEN
export OWNER_UUID

# Start the server as hytale user
su hytale -c "export PATH=\"$PATH\" && cd /home/hytale/server && \
    DEFAULT_PORT='${DEFAULT_PORT}' \
    SERVER_NAME='${SERVER_NAME}' \
    MAX_PLAYERS='${MAX_PLAYERS}' \
    VIEW_DISTANCE='${VIEW_DISTANCE}' \
    ENABLE_BACKUPS='${ENABLE_BACKUPS}' \
    BACKUP_FREQUENCY='${BACKUP_FREQUENCY}' \
    BACKUP_MAX_COUNT='${BACKUP_MAX_COUNT}' \
    BACKUP_DIR='${BACKUP_DIR}' \
    DISABLE_SENTRY='${DISABLE_SENTRY}' \
    USE_AOT_CACHE='${USE_AOT_CACHE}' \
    AUTH_MODE='${AUTH_MODE}' \
    ACCEPT_EARLY_PLUGINS='${ACCEPT_EARLY_PLUGINS}' \
    MIN_MEMORY='${MIN_MEMORY}' \
    MAX_MEMORY='${MAX_MEMORY}' \
    JVM_ARGS='${JVM_ARGS}' \
    PATCHLINE='${PATCHLINE}' \
    SESSION_TOKEN='${SESSION_TOKEN}' \
    IDENTITY_TOKEN='${IDENTITY_TOKEN}' \
    OWNER_UUID='${OWNER_UUID}' \
    ./start.sh" &

# Process ID of su
killpid="$!"
wait "$killpid"
