# Minecraft Quilt Server Manager

A comprehensive bash script for managing Minecraft Quilt servers with automatic dependency installation, interactive configuration, and session management.

## Features

- **Automatic dependency installation** - Installs Java 21, tmux, and curl
- **Interactive configuration** - Prompts for Minecraft version and Java memory settings
- **Session management** - Runs server in detachable tmux sessions
- **Multi-platform support** - Works on Ubuntu, Debian, Fedora, CentOS, RHEL, and Arch Linux
- **Configuration persistence** - Saves settings to reuse across sessions
- **Graceful server management** - Proper start/stop/restart functionality

## Requirements

- Linux operating system (Ubuntu, Debian, Fedora, CentOS, RHEL, or Arch Linux)
- Sudo privileges for initial setup
- Internet connection for downloading Java and server files
- At least 2GB RAM (4GB+ recommended)

## Installation

1. **Download the script**:
   ```bash
   curl -O https://raw.githubusercontent.com/sevanial/sevanial/main/mcserver.sh
   chmod +x mcserver.sh

   ```

2. **Run initial setup**:
   ```bash
   ./mcserver.sh setup
   ```

3. **Install the server**:
   ```bash
   ./mcserver.sh install
   ```

4. **Start the server**:
   ```bash
   ./mcserver.sh start
   ```

## Commands

### Primary Commands

| Command | Description |
|---------|-------------|
| `setup` | Install system dependencies and Java 21 |
| `install` | Download and install Quilt server (interactive) |
| `start` | Start the server in tmux session |
| `stop` | Stop the server gracefully |
| `console` | Connect to server console |
| `status` | Show server running status |
| `debug` | Show detailed system and server information |
| `config` | Display current configuration |

### First-Time Setup Workflow

```bash
# 1. Install dependencies and Java
./mcserver.sh setup

# 2. Install and configure server
./mcserver.sh install

# 3. Start the server
./mcserver.sh start
```

### Daily Usage

```bash
# Start server
./mcserver.sh start

# Connect to console
./mcserver.sh console

# Stop server
./mcserver.sh stop

# Check status
./mcserver.sh status
```

## Interactive Configuration

When running `./mcserver.sh install`, you'll be prompted for:

### Minecraft Version
```
Please enter the Minecraft version you want to install:
Examples: 1.21.6, 1.21.4, 1.20.1, 1.19.2
Minecraft version: 1.21.6
```

### Java Memory Options
```
Please enter Java options for the server:
Common options:
  -Xms4G -Xmx6G                (4-6GB RAM)
  -Xms2G -Xmx4G                (2-4GB RAM)
  -Xms8G -Xmx12G               (8-12GB RAM)
  -Xms1G -Xmx2G                (1-2GB RAM)

Press Enter for default (4-6GB): -Xms4G -Xmx6G 
Java options: -Xms2G -Xmx4G 
```

## Configuration Management

### Configuration File
Settings are automatically saved to `mcserver.conf`:
```bash
# Minecraft Server Configuration
MINECRAFT_VERSION="1.21.6"
JAVA_OPTS="-Xms4G -Xmx6G "
```

### Changing Configuration
- Run `./mcserver.sh install` again to change settings
- Edit `mcserver.conf` manually if needed
- View current config with `./mcserver.sh config`

## Memory Recommendations

| Server Size | Players | Recommended Settings |
|-------------|---------|---------------------|
| Small | 1-10 | `-Xms2G -Xmx4G ` |
| Medium | 10-20 | `-Xms4G -Xmx6G ` |
| Large | 20-50 | `-Xms8G -Xmx12G ` |
| Very Large | 50+ | `-Xms16G -Xmx24G ` |

## File Structure

```
./
├── mcserver.sh              # Main script
├── mcserver.conf            # Configuration file (auto-generated)
├── quilt-installer-*.jar    # Quilt installer (downloaded)
└── server/                  # Server directory
    ├── quilt-server-launch.jar
    ├── eula.txt
    ├── server.properties
    ├── logs/
    ├── world/
    └── mods/
```

## Console Management

### Connecting to Console
```bash
./mcserver.sh console
```

### Detaching from Console
- Press `Ctrl+B` then `D` to detach without stopping the server
- The server continues running in the background

### Common Console Commands
```
/stop                    # Stop the server
/list                    # List online players
/op <player>             # Give operator privileges
/tp <player1> <player2>  # Teleport players
/time set day            # Set time to day
/weather clear           # Clear weather
```

## Troubleshooting

### Java Version Issues
```bash
# Check Java version
java -version

# Set Java version on Arch Linux
sudo archlinux-java set java-21-openjdk

# Reload environment
source ~/.bashrc
```

### Server Won't Start
```bash
# Check debug information
./mcserver.sh debug

# Check server logs
tail -f server/logs/latest.log

# Test Java settings
cd server
java -Xms2G -Xmx4G  -jar quilt-server-launch.jar nogui
```

### Port Configuration
Edit `server/server.properties`:
```properties
server-port=25565
```

### Memory Issues
- Reduce `-Xms` and `-Xmx` values if server won't start
- Ensure system has enough available RAM
- Check system memory: `free -h`

## Security Considerations

### Firewall Configuration
```bash
# Ubuntu/Debian
sudo ufw allow 25565

# CentOS/RHEL/Fedora
sudo firewall-cmd --permanent --add-port=25565/tcp
sudo firewall-cmd --reload
```

### Running as Non-Root
- Never run the server as root user
- The script handles sudo only for system package installation
- Server itself runs under your user account

## Modding

### Adding Mods
1. Download `.jar` mod files
2. Place them in `server/mods/` directory
3. Restart the server: `./mcserver.sh stop && ./mcserver.sh start`

### Fabric vs Quilt
- This script uses Quilt (Fabric fork)
- Most Fabric mods work with Quilt
- Some mods may require Quilt-specific versions

## Backup Recommendations

### World Backup
```bash
# Stop server first
./mcserver.sh stop

# Backup world
tar -czf world-backup-$(date +%Y%m%d).tar.gz server/world/

# Restart server
./mcserver.sh start
```

### Full Server Backup
```bash
./mcserver.sh stop
tar -czf server-backup-$(date +%Y%m%d).tar.gz server/
./mcserver.sh start
```

## Performance Optimization

### Additional Optimizations
You can add these to your Java options:
```bash
-XX:+UnlockExperimentalVMOptions
-XX:+UseG1GC
-XX:G1NewSizePercent=20
-XX:G1ReservePercent=20
-XX:MaxGCPauseMillis=50
-XX:G1HeapRegionSize=32M
```

## Support

### Getting Help
```bash
./mcserver.sh help
./mcserver.sh debug
```

### Log Files
- Server logs: `server/logs/latest.log`
- Crash reports: `server/crash-reports/`

### Common Issues
1. **Java version mismatch** - Run `./mcserver.sh setup`
2. **Server won't start** - Check `./mcserver.sh debug`
3. **Memory errors** - Reduce `-Xmx` value
4. **Port conflicts** - Change port in `server.properties`

## License

This script is provided as-is for educational and personal use. Minecraft and Quilt are trademarks of their respective owners.
