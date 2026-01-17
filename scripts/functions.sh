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
  
  local SERVER_FILES="/home/hytale/server-files"
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
  
  if [ ! -f "$CREDENTIALS_FILE" ]; then
    # First boot - no credentials yet, skip version check
    LogInfo "First time setup - authentication required"
  else
    # Check latest available version
    LogInfo "Checking latest version..."
    latest_version=$(./$(basename "$DOWNLOADER_EXEC") -print-version)
    
    if [ -z "$latest_version" ]; then
      LogError "Failed to get latest version"
      return 1
    fi
    
    LogInfo "Latest available version: $latest_version"
    
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
  ./$(basename "$DOWNLOADER_EXEC") -download-path "$SERVER_FILES/game.zip" -patchline "$PATCHLINE" || {
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

  # Remove outdated AOT cache only if this was an update
  if [ -n "$current_version" ] && [ "$current_version" != "$latest_version" ]; then
    if [ -f "$SERVER_FILES/Server/HytaleServer.aot" ]; then
      LogWarn "Removing outdated AOT cache file (HytaleServer.aot) after update"
      rm -f "$SERVER_FILES/Server/HytaleServer.aot"
    fi
  fi

  # Save version
  echo "$latest_version" > "$VERSION_FILE"

  LogSuccess "Server download completed (version $latest_version)"
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
