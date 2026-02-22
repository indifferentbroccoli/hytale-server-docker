#!/bin/bash

#================
# Log Definitions
#================
export LINE='\n'                        # Line Break
export RESET='\033[0m'                  # Text Reset
export WhiteText='\033[0;37m'           # White

# Bold
export RedBoldText='\033[1;31m'         # Red
export GreenBoldText='\033[1;32m'       # Green
export YellowBoldText='\033[1;33m'      # Yellow
export CyanBoldText='\033[1;36m'        # Cyan
#================
# End Log Definitions
#================

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"
  printf "$color%s$RESET$LINE" "$prefix$message$suffix"
}

download_server() {
  LogAction "Checking server version"
  
  : "${SERVER_FILES:?SERVER_FILES not set}"

  # local SERVER_FILES="/home/hytale/server-files"
  local DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
  local DOWNLOADER_ZIP="$SERVER_FILES/hytale-downloader.zip"
  local DOWNLOADER_DIR="$SERVER_FILES/downloader"
  local VERSION_FILE="$SERVER_FILES/.server-version"
  
  mkdir -p "$SERVER_FILES"
  cd "$SERVER_FILES" || exit 1
  
  # Ensure we have the downloader
  if [ ! -d "$DOWNLOADER_DIR" ] || [ -z "$(find "$DOWNLOADER_DIR" -name "hytale-downloader-linux-*" -type f)" ]; then
    LogInfo "Downloading Hytale Downloader..."
    wget -q "$DOWNLOADER_URL" -O "$DOWNLOADER_ZIP" || {
      LogError "Failed to download Hytale Downloader"
      return 1
    }
    
    mkdir -p "$DOWNLOADER_DIR"
    unzip -o -q "$DOWNLOADER_ZIP" -d "$DOWNLOADER_DIR" || {
      LogError "Failed to extract Hytale Downloader"
      return 1
    }
    rm "$DOWNLOADER_ZIP"
  fi
  
  # Find the hytale-downloader executable
  DOWNLOADER_EXEC=$(find "$DOWNLOADER_DIR" -name "hytale-downloader-linux-*" -type f | head -1)
  if [ -z "$DOWNLOADER_EXEC" ]; then
    LogError "Could not find hytale-downloader executable"
    return 1
  fi
  
  chmod +x "$DOWNLOADER_EXEC"
  cd "$(dirname "$DOWNLOADER_EXEC")" || exit 1
  
  # Check if credentials exist (needed for version check)
  local CREDENTIALS_FILE="$DOWNLOADER_DIR/.hytale-downloader-credentials.json"
  local latest_version=""
  local current_version=""
  : "${PATCHLINE:?PATCHLINE not set}"
  local DOWNLOADER_BASENAME
  DOWNLOADER_BASENAME="$(basename "$DOWNLOADER_EXEC")"
  
  # Determine how to run the downloader
  local DOWNLOADER_CMD="./$DOWNLOADER_BASENAME"
  if ! ./$DOWNLOADER_BASENAME -h &>/dev/null; then
    # Direct execution failed, try QEMU
    if [ -x "/usr/bin/qemu-x86_64-static" ]; then
      LogInfo "Using QEMU emulation for x86_64 binary"
      DOWNLOADER_CMD="/usr/bin/qemu-x86_64-static ./$DOWNLOADER_BASENAME"
    elif [ -x "/usr/bin/qemu-x86_64" ]; then
      LogInfo "Using QEMU emulation for x86_64 binary"
      DOWNLOADER_CMD="/usr/bin/qemu-x86_64 ./$DOWNLOADER_BASENAME"
    else
      LogError "Cannot execute x86_64 binary."
      return 1
    fi
  fi
  
  if [ "$PATCHLINE" != "release" ]; then
    DOWNLOADER_CMD="$DOWNLOADER_CMD -patchline $PATCHLINE"
    LogInfo "Using patchline: $PATCHLINE"
  fi
  
  if [ ! -f "$CREDENTIALS_FILE" ]; then
    # First boot - no credentials yet, skip version check
    LogInfo "First time setup - authentication required"
  else
    # Check latest available version
    LogInfo "Checking latest version..."
    if latest_version=$(eval "$DOWNLOADER_CMD -print-version" 2>/dev/null) && [ -n "$latest_version" ]; then
      LogInfo "Latest available version: $latest_version"
    else
      LogError "Failed to get latest version"
      return 1
    fi
    
    # Check current installed version
    if [ -f "$VERSION_FILE" ]; then
      current_version=$(cat "$VERSION_FILE")
      LogInfo "Current installed version: $current_version"
    fi
    
    # Compare versions
    if [ -f "$SERVER_FILES/Server/HytaleServer.jar" ] && [ "$current_version" = "$latest_version" ]; then
      LogSuccess "Server is up to date (version $latest_version)"
      return 0
    fi
    
    # Download needed
    if [ -f "$SERVER_FILES/Server/HytaleServer.jar" ]; then
      LogInfo "Update available: $current_version -> $latest_version"
    fi
  fi
  
  LogInfo "Downloading server files (this may take a while)..."
  cd "$(dirname "$DOWNLOADER_EXEC")" || exit 1
  eval "$DOWNLOADER_CMD -download-path '$SERVER_FILES/game.zip'" || {
    LogError "Failed to download server files"
    return 1
  }
  
  # Check if authentication was successful
  if [ -f "$DOWNLOADER_DIR/.hytale-downloader-credentials.json" ]; then
    LogSuccess "Hytale Authentication Successful"
  fi
  
  # Extract the files
  LogInfo "Extracting server files..."
  cd "$SERVER_FILES" || exit 1
  unzip -o -q game.zip || {
    LogError "Failed to extract server files"
    return 1
  }
  rm game.zip
  
  # Verify files exist
  if [ ! -f "$SERVER_FILES/Server/HytaleServer.jar" ]; then
    LogError "HytaleServer.jar not found after download"
    return 1
  fi

  # Get version if we don't have it yet (first boot or version check was skipped)
  if [ -z "$latest_version" ]; then
    cd "$(dirname "$DOWNLOADER_EXEC")" || exit 1
    if latest_version=$(eval "$DOWNLOADER_CMD -print-version" 2>/dev/null) && [ -n "$latest_version" ]; then
      LogInfo "Server version: $latest_version"
    fi
  fi

  # Remove outdated AOT cache only if this was an update
  if [ -n "$current_version" ] && [ "$current_version" != "$latest_version" ]; then
    if [ -f "$SERVER_FILES/Server/HytaleServer.aot" ]; then
      LogWarn "Removing outdated AOT cache file (HytaleServer.aot) after update"
      rm -f "$SERVER_FILES/Server/HytaleServer.aot"
    fi
  fi

  # Save version
  if [ -n "$latest_version" ]; then
    echo "$latest_version" > "$VERSION_FILE"
    LogSuccess "Server download completed (version $latest_version)"
  else
    LogSuccess "Server download completed"
  fi
}

# Attempt to shutdown the server gracefully
# Returns 0 if it is shutdown
# Returns 1 if it is not able to be shutdown
shutdown_server() {
    local return_val=0
    LogAction "Attempting graceful server shutdown"
    
    # Find the process ID
    local pid=$(pgrep -f HytaleServer.jar)
    
    if [ -n "$pid" ]; then
        # Send SIGTERM to allow graceful shutdown
        kill -SIGTERM "$pid"
        
        # Wait up to 30 seconds for process to exit
        local count=0
        while [ $count -lt 30 ] && kill -0 "$pid" 2>/dev/null; do
            sleep 1
            count=$((count + 1))
        done
        
        # Check if process is still running
        if kill -0 "$pid" 2>/dev/null; then
            LogWarn "Server did not shutdown gracefully, forcing shutdown"
            return_val=1
        else
            LogSuccess "Server shutdown gracefully"
        fi
    else
        LogWarn "Server process not found"
        return_val=1
    fi
    
    return "$return_val"
}


#============================
# Rootless / permissions logic
#============================
# We want `docker compose up` to work without specifying `user:`.
#
# - Rootful Docker: container root == host root for bind-mounts. If we stay root,
#   files created on the host bind mount become owned by root (bad UX). So we
#   *drop privileges* to match the ownership of $SERVER_FILES (or PUID/PGID if set).
#
# - Rootless Docker: container root is mapped to the invoking host user via userns.
#   In that case, staying as container root results in host-owned files (good),
#   and attempting to chown a bind mount often fails. So we avoid chown and do
#   not try to drop privileges.

is_userns_rootless() {
    # If we have user namespace mappings, we are very likely in rootless mode.
    # Typical rootless: 0 100000 65536
    # Rootful often:   0 0 4294967295
    local map
    map="$(cat /proc/self/uid_map 2>/dev/null | head -n 1)"
    if echo "$map" | grep -Eq '^\s*0\s+0\s+'; then
        return 1
    fi
    # If 0 is not mapped to 0, we're in userns.
    return 0
}

detect_target_ids() {
    # Defaults (kept for compatibility with README)
    PUID="${PUID:-1000}"
    PGID="${PGID:-1000}"

    # If server-files is a bind mount and exists, prefer its ownership.
    # But ignore root:root (often happens when Docker auto-creates the host dir).
    if [ -d "${SERVER_FILES}" ]; then
        local st_uid st_gid
        st_uid="$(stat -c '%u' "${SERVER_FILES}" 2>/dev/null || echo "")"
        st_gid="$(stat -c '%g' "${SERVER_FILES}" 2>/dev/null || echo "")"
        if [ -n "$st_uid" ] && [ -n "$st_gid" ]; then
            # If user did not explicitly set PUID/PGID, use the directory ownership.
            if [ -z "${PUID_EXPLICIT}" ] && [ "$st_uid" != "0" ]; then PUID="$st_uid"; fi
            if [ -z "${PGID_EXPLICIT}" ] && [ "$st_gid" != "0" ]; then PGID="$st_gid"; fi
        fi
    fi
}

maybe_drop_privileges_and_reexec() {
    local euid_now
    euid_now="$(id -u)"
    if [ "$euid_now" -ne 0 ]; then
        return 0
    fi

    if is_userns_rootless; then
        LogInfo "Detected user namespace mapping (rootless engine). Staying as container root to preserve host ownership."
        return 0
    fi

    # Rootful: drop privileges unless we were already asked to run as root.
    # We support optional explicit PUID/PGID and otherwise follow bind-mount ownership.
    detect_target_ids
    LogInfo "Rootful engine detected. Will run server as UID:GID ${PUID}:${PGID} to avoid root-owned host files."

    # Ensure group exists / is correct
    if getent group "${PGID}" >/dev/null 2>&1; then
        :
    else
        groupadd -g "${PGID}" hytalegrp >/dev/null 2>&1 || true
    fi

    # Ensure user exists / is correct (getent supports numeric uid lookups)
    if getent passwd "${PUID}" >/dev/null 2>&1; then
        :
    else
        useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash hytaleusr >/dev/null 2>&1 || true
    fi

    # Best-effort permission fixes. These may fail on some bind mounts; don't crash.
    mkdir -p "${SERVER_FILES}" "${BACKUP_DIR}" 2>/dev/null || true
    chown -R "${PUID}:${PGID}" "${SERVER_ROOT}" 2>/dev/null || true
    chown -R "${PUID}:${PGID}" "${SERVER_FILES}" 2>/dev/null || true

    exec gosu "${PUID}:${PGID}" "$0" "$@"
}