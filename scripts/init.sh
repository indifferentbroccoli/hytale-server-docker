#!/bin/bash
# set -euo pipefail

# shellcheck source=scripts/functions.sh
source "/home/hytale/server/functions.sh"

# Global variable for the server PID
server_pid_1=""

# shellcheck disable=SC2317
term_handler() {
    LogInfo "Received termination signal, attempting graceful shutdown..."

    # call shutdown function first:
    if ! shutdown_server; then
        LogWarn "Graceful shutdown failed, sending SIGTERM to HytaleServer.jar..."
        # Fallback to kill the JVM directly if needed
        pkill -f HytaleServer.jar || true
    fi

    # If we know the server PID, wait for it to exit
    if [[ -n "${server_pid_1}" ]]; then
        LogInfo "Waiting for server process (PID=${server_pid_1}) to exit..."
        wait "${server_pid_1}" 2>/dev/null || true
    fi

    LogInfo "Shutdown handler completed, exiting init script."
    exit 0
}

# Install traps early
trap 'term_handler' SIGTERM SIGINT

LogAction "Set file permissions"
EUID_NOW="$(id -u)"
LogAction ${EUID_NOW}

# Mark whether PUID/PGID were explicitly provided
[ -n "${PUID+x}" ] && PUID_EXPLICIT=1 || PUID_EXPLICIT=""
[ -n "${PGID+x}" ] && PGID_EXPLICIT=1 || PGID_EXPLICIT=""

maybe_drop_privileges_and_reexec "$@"

cat /branding

# Set up persistent machine-id for encrypted auth
: "${SERVER_FILES:?SERVER_FILES not set}"
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
    
    # Best-effort: chown may fail under rootless userns or on bind mounts.
    if [ "$(id -u)" -eq 0 ] && ! is_userns_rootless; then
        detect_target_ids
        chown -R "${PUID}:${PGID}" "$MACHINE_ID_DIR" 2>/dev/null || true
    fi
fi

: "${DOWNLOAD_ON_START:?DOWNLOAD_ON_START not set}"
if [ "${DOWNLOAD_ON_START}" = "true" ]; then
    download_server
else
    LogWarn "DOWNLOAD_ON_START is set to false, skipping server download"
fi



trap 'term_handler' SIGTERM

cd "${SERVER_ROOT}" || exit 1

LogInfo "Starting Hytale server via ./start.sh"

# Start the server in the background and capture its PID
./start.sh &
server_pid_1=$!

# Wait for the server process; this keeps the script running
wait "${server_pid_1}"
exit_code=$?

LogInfo "Server process exited with code ${exit_code}"
exit "${exit_code}"