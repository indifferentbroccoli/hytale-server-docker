#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/hytale/server/functions.sh"

SERVER_FILES="/home/hytale/server-files"

cd "$SERVER_FILES" || exit

LogAction "Starting Hytale Dedicated Server"

# Set defaults if not provided
DEFAULT_PORT="${DEFAULT_PORT:-5520}"
SERVER_NAME="${SERVER_NAME:-hytale-server}"
MAX_PLAYERS="${MAX_PLAYERS:-20}"
VIEW_DISTANCE="${VIEW_DISTANCE:-12}"
ENABLE_BACKUPS="${ENABLE_BACKUPS:-false}"
BACKUP_FREQUENCY="${BACKUP_FREQUENCY:-30}"
BACKUP_MAX_COUNT="${BACKUP_MAX_COUNT:-5}"
BACKUP_DIR="${BACKUP_DIR:-/home/hytale/server-files/backups}"
DISABLE_SENTRY="${DISABLE_SENTRY:-true}"
USE_AOT_CACHE="${USE_AOT_CACHE:-true}"
AUTH_MODE="${AUTH_MODE:-authenticated}"
ACCEPT_EARLY_PLUGINS="${ACCEPT_EARLY_PLUGINS:-false}"
MAX_MEMORY="${MAX_MEMORY:-8192}"

# Check if HytaleServer.jar exists
SERVER_JAR="$SERVER_FILES/Server/HytaleServer.jar"

if [ ! -f "$SERVER_JAR" ]; then
    LogError "Could not find HytaleServer.jar at: $SERVER_JAR"
    LogError "Please ensure the server files are properly downloaded."
    exit 1
fi

LogInfo "Found server JAR: ${SERVER_JAR}"
LogInfo "Server starting on port ${DEFAULT_PORT}"
LogInfo "Server name: ${SERVER_NAME}"
LogInfo "Max players: ${MAX_PLAYERS}"
LogInfo "View distance: ${VIEW_DISTANCE} chunks ($(($VIEW_DISTANCE * 32)) blocks)"
LogInfo "Authentication mode: ${AUTH_MODE}"

# Build Java command with memory settings
if [ -n "${MIN_MEMORY}" ]; then
    JVM_MEMORY="-Xms${MIN_MEMORY} -Xmx${MAX_MEMORY}"
    LogInfo "Memory: ${MIN_MEMORY} min, ${MAX_MEMORY} max"
else
    JVM_MEMORY="-Xmx${MAX_MEMORY}"
    LogInfo "Memory: ${MAX_MEMORY} max (no minimum set)"
fi
# Build the startup command
STARTUP_CMD="java ${JVM_MEMORY}"

# Add AOT cache if enabled
if [ "${USE_AOT_CACHE}" = "true" ] && [ -f "${SERVER_FILES}/Server/HytaleServer.aot" ]; then
    STARTUP_CMD="${STARTUP_CMD} -XX:AOTCache=${SERVER_FILES}/Server/HytaleServer.aot"
    LogInfo "Using AOT cache for faster startup"
fi

# Add custom JVM arguments if provided
if [ -n "${JVM_ARGS}" ]; then
    STARTUP_CMD="${STARTUP_CMD} ${JVM_ARGS}"
    LogInfo "Custom JVM args: ${JVM_ARGS}"
fi

# GSP token passthrough (if provided)
if [ -n "${SESSION_TOKEN}" ] && [ -n "${IDENTITY_TOKEN}" ]; then
    export HYTALE_SERVER_SESSION_TOKEN="${SESSION_TOKEN}"
    export HYTALE_SERVER_IDENTITY_TOKEN="${IDENTITY_TOKEN}"
    [ -n "${OWNER_UUID}" ] && STARTUP_CMD="${STARTUP_CMD} --owner-uuid ${OWNER_UUID}"
fi

# Add the JAR and required arguments
STARTUP_CMD="${STARTUP_CMD} -jar ${SERVER_JAR}"
STARTUP_CMD="${STARTUP_CMD} --assets /home/hytale/server-files/Assets.zip"
STARTUP_CMD="${STARTUP_CMD} --bind 0.0.0.0:${DEFAULT_PORT}"
STARTUP_CMD="${STARTUP_CMD} --auth-mode ${AUTH_MODE}"

# Add optional arguments
if [ "${DISABLE_SENTRY}" = "true" ]; then
    STARTUP_CMD="${STARTUP_CMD} --disable-sentry"
fi

if [ "${ACCEPT_EARLY_PLUGINS}" = "true" ]; then
    STARTUP_CMD="${STARTUP_CMD} --accept-early-plugins"
fi

if [ "${ENABLE_BACKUPS}" = "true" ]; then
    STARTUP_CMD="${STARTUP_CMD} --backup --backup-dir $BACKUP_DIR --backup-frequency $BACKUP_FREQUENCY --backup-max-count $BACKUP_MAX_COUNT"
    LogInfo "Automatic backups enabled (every ${BACKUP_FREQUENCY} minutes to ${BACKUP_DIR}, retaining up to ${BACKUP_MAX_COUNT})"
fi

LogInfo "Starting Hytale server..."

# Create a named pipe for sending commands to the server
FIFO="/tmp/hytale_input_$$"
mkfifo "$FIFO"

# Start the server with the fifo as stdin
eval "$STARTUP_CMD" < "$FIFO" &
SERVER_PID=$!

# Open the fifo for writing (keeps it open)
exec 3>"$FIFO"

# Monitor logs and send auth command when ready
(
    sleep 5
    LOG_FILE=$(ls -t /home/hytale/server-files/logs/*_server.log 2>/dev/null | head -1)
    if [ -n "$LOG_FILE" ]; then
        tail -f "$LOG_FILE" | while read -r line; do
            if echo "$line" | grep -q "Hytale Server Booted!"; then
                sleep 2
                echo "/auth login device" >&3
                LogSuccess "Sent auth command to server"
            fi
            
            if echo "$line" | grep -qE "Authentication successful!|Server is already authenticated."; then
                sleep 1
                echo "/auth persistence Encrypted" >&3
                LogSuccess "Sent persistence command to server"
                break
            fi
        done
    fi
) &

# Wait for the server process
wait $SERVER_PID
EXIT_CODE=$?

# Cleanup
exec 3>&-
rm -f "$FIFO"

exit $EXIT_CODE
