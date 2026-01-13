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
BACKUP_DIR="${BACKUP_DIR:-/home/hytale/server-files/backups}"
DISABLE_SENTRY="${DISABLE_SENTRY:-true}"
USE_AOT_CACHE="${USE_AOT_CACHE:-true}"
AUTH_MODE="${AUTH_MODE:-authenticated}"
ACCEPT_EARLY_PLUGINS="${ACCEPT_EARLY_PLUGINS:-false}"
MAX_MEMORY="${MAX_MEMORY:-8192}"

# Check if HytaleServer.jar exists
SERVER_JAR="$SERVER_FILES/Server/HytaleServer.jar"
ASSETS_ZIP="$SERVER_FILES/Assets.zip"

if [ ! -f "$SERVER_JAR" ]; then
    LogError "Could not find HytaleServer.jar at: $SERVER_JAR"
    LogError "Please ensure the server files are properly downloaded."
    exit 1
fi

if [ ! -f "$ASSETS_ZIP" ]; then
    LogError "Could not find Assets.zip at: $ASSETS_ZIP"
    LogError "Please ensure the server files are properly downloaded."
    exit 1
fi

LogInfo "Found server JAR: ${SERVER_JAR}"
LogInfo "Found assets: ${ASSETS_ZIP}"
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
STARTUP_CMD="${STARTUP_CMD} --assets ${ASSETS_ZIP}"
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
    STARTUP_CMD="${STARTUP_CMD} --backup --backup-dir $BACKUP_DIR --backup-frequency $BACKUP_FREQUENCY"
    LogInfo "Automatic backups enabled (every ${BACKUP_FREQUENCY} minutes to ${BACKUP_DIR})"
fi

LogInfo "Starting Hytale server..."

# Start the server
eval "$STARTUP_CMD"
