<!-- markdownlint-disable-next-line -->
![marketing_assets_banner](https://github.com/user-attachments/assets/b8b4ae5c-06bb-46a7-8d94-903a04595036)
[![GitHub License](https://img.shields.io/github/license/indifferentbroccoli/hytale-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/hytale-server-docker/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/indifferentbroccoli/hytale-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/hytale-server-docker/releases)
[![GitHub Repo stars](https://img.shields.io/github/stars/indifferentbroccoli/hytale-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/hytale-server-docker)
[![Discord](https://img.shields.io/discord/798321161082896395?style=for-the-badge&label=Discord&labelColor=5865F2&color=6aa84f)](https://discord.gg/indifferentbroccoli)
[![Docker Pulls](https://img.shields.io/docker/pulls/indifferentbroccoli/hytale-server-docker?style=for-the-badge&color=6aa84g)](https://hub.docker.com/r/indifferentbroccoli/hytale-server-docker)

Game server hosting

Fast RAM, high-speed internet

Eat lag for breakfast

[Try our Hytale server hosting free for 2 days!](https://indifferentbroccoli.com/hytale-server-hosting)

## Hytale Dedicated Server Docker

A Docker container for running a Hytale dedicated server with automatic downloading and updates using the official Hytale Downloader CLI.

## Server Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU      | 4 cores | 8+ cores    |
| RAM      | 4GB     | 8GB+        |
| Storage  | 10GB    | 20GB        |

> [!NOTE]
> - Hytale requires **Java 25** (included in the Docker image)
> - Server resource usage depends heavily on player count and view distance
> - Higher view distances significantly increase RAM usage
> - Hytale uses **QUIC over UDP** (not TCP) on port **5520**
> - **ARM64/Apple Silicon supported** - The x86_64 downloader runs via QEMU emulation, while the Java server runs natively

> [!IMPORTANT]
> **First-Time Setup: Authentication Required**
> 
> On first startup, you'll need to authenticate via your browser. The server will display a URL in the console - just visit it and log in with your Hytale account. You will then need to authorize again from the link that appears once the server has started.

## How to use

Copy the `.env.example` file to a new file called `.env` and adjust the settings as needed.

### Quick Start

```bash
# 1. Start server
docker-compose up -d

# 2. Check logs for OAuth URL
docker-compose logs -f

# 3. Visit the URL in your browser and authenticate
# Server continues automatically after authentication
```

### Docker Compose

Then use either `docker compose` or `docker run`:

```yaml
services:
  hytale:
    image: indifferentbroccoli/hytale-server-docker
    restart: unless-stopped
    container_name: hytale
    stop_grace_period: 30s
    ports:
      - 5520:5520/udp
    env_file:
      - .env
    volumes:
      - ./server-files:/home/hytale/server-files
    stdin_open: true
    tty: true
```

Then run:

```bash
docker-compose up -d
```

### Docker Run

```bash
docker run -d \
    --restart unless-stopped \
    --name hytale \
    --stop-timeout 30 \
    -p 5520:5520/udp \
    --env-file .env \
    -v ./server-files:/home/hytale/server-files \
    -it \
    indifferentbroccoli/hytale-server-docker
```

## Environment Variables

You can use the following values to change the settings of the server on boot.

| Variable               | Default              | Description                                                                           |
|------------------------|----------------------|---------------------------------------------------------------------------------------|
| PUID                   | 1000                 | User ID for file permissions                                                          |
| PGID                   | 1000                 | Group ID for file permissions                                                         |
| SERVER_NAME            | hytale-server-docker | Name of the server                                                                    |
| DEFAULT_PORT           | 5520                 | The port the server listens on (UDP only)                            |
| MAX_PLAYERS            | 20                   | Maximum number of players allowed on the server                                       |
| VIEW_DISTANCE          | 12                   | View distance in chunks (12 chunks = 384 blocks). Higher values require more RAM     |
| AUTH_MODE              | authenticated        | Authentication mode: `authenticated` or `offline`                                     |
| ENABLE_BACKUPS         | false                | Enable automatic world backups                                                        |
| BACKUP_FREQUENCY       | 30                   | Backup interval in minutes (if backups are enabled)                                   |
| BACKUP_MAX_COUNT       | 5                    | How many previous backups to retain                                                   |
| BACKUP_DIR             | /home/hytale/server-files/backups | Directory path for storing backups                              |
| DISABLE_SENTRY         | true                 | Disable Sentry crash reporting                                                        |
| USE_AOT_CACHE          | true                 | Use Ahead-of-Time compilation cache for faster startup                                |
| ACCEPT_EARLY_PLUGINS   | false                | Allow early plugins (may cause stability issues)                                      |
| MIN_MEMORY             |                      | Minimum JVM heap size (e.g., 4G). Leave unset to omit -Xms flag                      |
| MAX_MEMORY             | 8G                   | Maximum JVM heap size (e.g., 8G, 8192M)                                               |
| JVM_ARGS               |                      | Custom JVM arguments (optional)                                                       |
| PATCHLINE              | release              | Selects the patchline for the game (`release` or `pre-release`)                       |
| DOWNLOAD_ON_START      | true                 | Automatically download/update server files on startup                                 |

## Port Configuration

Hytale uses the **QUIC protocol over UDP** (not TCP). Make sure to:

1. **Open UDP port 5520** (or your custom port) in your firewall
2. **Forward UDP port 5520** in your router if hosting from home
3. Configure firewall rules for UDP only


## File Structure

After first run, the following structure will be created in your `server-files` directory:

```
server-files/
├── Server/
│   ├── HytaleServer.jar       # Main server executable
│   └── HytaleServer.aot       # AOT cache for faster startup
├── Assets.zip                 # Game assets
├── downloader/                # Hytale downloader CLI
├── .cache/                    # Optimized file cache
├── logs/                      # Server log files
├── mods/                      # Installed mods (place .jar or .zip files here)
├── universe/                  # World and player save data
│   └── worlds/                # Individual world folders
├── bans.json                  # Banned players
├── config.json                # Server configuration
├── permissions.json           # Permission configuration
└── whitelist.json             # Whitelisted players
```

## Installing Mods

1. Download mods (`.jar` or `.zip` files) from sources like [CurseForge](https://www.curseforge.com/hytale)
2. Place them in the `server-files/mods/` directory
3. Restart the server

## View Distance & Performance

View distance is the primary driver for RAM usage:

- **Default:** 12 chunks (384 blocks) ≈ 24 Minecraft chunks
- **Recommended Max:** 12 chunks for optimal performance
- **RAM Impact:** Higher view distances exponentially increase memory requirements

Tune `MAX_MEMORY` and `VIEW_DISTANCE` based on:
- Number of concurrent players
- How spread out players are in the world
- Available server resources

## Useful Commands

### View server logs
```bash
docker logs hytale -f
# or
docker-compose logs -f
```

### Stop the server
```bash
docker-compose down
```

### Restart the server
```bash
docker-compose restart
```

### Update server files
Server files are automatically updated on restart if `DOWNLOAD_ON_START=true`. To force an update:
```bash
docker-compose restart
```

### Send commands to the server console
```bash
# Send a command to the running server
docker exec -u hytale hytale command.sh "/auth status"

# Other examples
docker exec -u hytale hytale command.sh "/eventtitle 'Hello Indifferent Server'"
docker exec -u hytale hytale command.sh "/kick player"
docker exec -u hytale hytale command.sh "/op add player"
```

## Support

- [Official Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [GitHub Issues](https://github.com/indifferentbroccoli/hytale-server-docker/issues)


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
