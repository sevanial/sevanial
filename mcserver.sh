#!/bin/bash
# Minecraft Quilt Server Manager
# Usage: ./mcserver.sh {setup|install|start|stop|console|debug}

SESSION="mcserver"
SERVER_DIR="./server"
QUILT_VERSION="0.12.1"
MINECRAFT_VERSION=""
REQUIRED_JAVA_VERSION="21"
INSTALLER_URL="https://maven.quiltmc.org/repository/release/org/quiltmc/quilt-installer/${QUILT_VERSION}/quilt-installer-${QUILT_VERSION}.jar"
JAVA_OPTS=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

prompt_minecraft_version() {
    echo ""
    echo "Please enter the Minecraft version you want to install:"
    echo "Examples: 1.21.6, 1.21.4, 1.20.1, 1.19.2"
    echo -n "Minecraft version: "
    read -r MINECRAFT_VERSION

    if [[ -z "$MINECRAFT_VERSION" ]]; then
        error "Minecraft version cannot be empty"
        return 1
    fi

    log "Selected Minecraft version: $MINECRAFT_VERSION"
    return 0
}

prompt_java_opts() {
    echo ""
    echo "Please enter Java options for the server:"
    echo "Common options:"
    echo "  -Xms4G -Xmx6G                (4-6GB RAM)"
    echo "  -Xms2G -Xmx4G                (2-4GB RAM)"
    echo "  -Xms8G -Xmx12G               (8-12GB RAM)"
    echo "  -Xms1G -Xmx2G                (1-2GB RAM)"
    echo ""
    echo "Press Enter for default (4-6GB): -Xms4G -Xmx6G "
    echo -n "Java options: "
    read -r JAVA_OPTS

    if [[ -z "$JAVA_OPTS" ]]; then
        JAVA_OPTS="-Xms4G -Xmx6G "
        log "Using default Java options: $JAVA_OPTS"
    else
        log "Using custom Java options: $JAVA_OPTS"
    fi

    return 0
}

save_config() {
    local config_file="mcserver.conf"
    cat > "$config_file" << EOF
# Minecraft Server Configuration
MINECRAFT_VERSION="$MINECRAFT_VERSION"
JAVA_OPTS="$JAVA_OPTS"
EOF
    log "Configuration saved to $config_file"
}

load_config() {
    local config_file="mcserver.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log "Configuration loaded from $config_file"
        log "Minecraft version: $MINECRAFT_VERSION"
        log "Java options: $JAVA_OPTS"
        return 0
    fi
    return 1
}

is_running() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

get_java_version() {
    if command -v java >/dev/null 2>&1; then
        # Try multiple methods to get Java version
        local version_output=$(java -version 2>&1 | head -1)

        # Handle different Java version formats
        if [[ $version_output =~ \"([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
            # Old format like "1.8.0_xxx" -> extract major version
            local major=${BASH_REMATCH[1]}
            local minor=${BASH_REMATCH[2]}
            if [[ $major == "1" ]]; then
                echo $minor
            else
                echo $major
            fi
        elif [[ $version_output =~ \"([0-9]+) ]]; then
            # New format like "21.0.7" -> extract major version
            echo ${BASH_REMATCH[1]}
        else
            # Fallback method
            java -version 2>&1 | head -1 | sed 's/.*version "\(.*\)".*/\1/' | cut -d'.' -f1 | sed 's/^1\.//'
        fi
    else
        echo "0"
    fi
}

check_java() {
    local current_version=$(get_java_version)
    if [[ "$current_version" -ge "$REQUIRED_JAVA_VERSION" ]]; then
        return 0
    fi
    return 1
}

install_java() {
    log "Installing Java $REQUIRED_JAVA_VERSION..."

    # Detect OS and install Java accordingly
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y openjdk-$REQUIRED_JAVA_VERSION-jdk
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora/CentOS/RHEL
        sudo dnf install -y java-$REQUIRED_JAVA_VERSION-openjdk-devel
    elif command -v yum >/dev/null 2>&1; then
        # Older CentOS/RHEL
        sudo yum install -y java-$REQUIRED_JAVA_VERSION-openjdk-devel
    elif command -v pacman >/dev/null 2>&1; then
        # Arch Linux
        sudo pacman -S --noconfirm jdk$REQUIRED_JAVA_VERSION-openjdk
    else
        error "Unsupported package manager. Please install Java $REQUIRED_JAVA_VERSION manually."
        error "Visit: https://adoptium.net/temurin/releases/"
        return 1
    fi

    # Set JAVA_HOME and update PATH for current session
    if [[ -d "/usr/lib/jvm/java-$REQUIRED_JAVA_VERSION-openjdk" ]]; then
        export JAVA_HOME="/usr/lib/jvm/java-$REQUIRED_JAVA_VERSION-openjdk"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi

    # Set as default if multiple versions exist
    if command -v update-alternatives >/dev/null 2>&1; then
        log "Setting Java $REQUIRED_JAVA_VERSION as default..."
        sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-$REQUIRED_JAVA_VERSION-openjdk*/bin/java 1000 2>/dev/null || true
        sudo update-alternatives --set java /usr/lib/jvm/java-$REQUIRED_JAVA_VERSION-openjdk*/bin/java 2>/dev/null || true
    fi

    # For Arch Linux, also try archlinux-java
    if command -v archlinux-java >/dev/null 2>&1; then
        log "Setting Java $REQUIRED_JAVA_VERSION as default using archlinux-java..."
        sudo archlinux-java set java-$REQUIRED_JAVA_VERSION-openjdk 2>/dev/null || true
    fi

    log "Java installation complete!"
}

install_dependencies() {
    log "Installing system dependencies..."

    # Install tmux if not present
    if ! command -v tmux >/dev/null 2>&1; then
        log "Installing tmux..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y tmux
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y tmux
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y tmux
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm tmux
        else
            error "Please install tmux manually"
            return 1
        fi
    fi

    # Install curl if not present
    if ! command -v curl >/dev/null 2>&1; then
        log "Installing curl..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y curl
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y curl
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y curl
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm curl
        fi
    fi

    log "Dependencies installed!"
}

setup() {
    log "Setting up Minecraft server environment..."

    # Install system dependencies
    install_dependencies

    # Check and install Java if needed
    if ! check_java; then
        local current_version=$(get_java_version)
        warn "Java $REQUIRED_JAVA_VERSION required, but found version $current_version"
        log "Installing Java $REQUIRED_JAVA_VERSION..."
        install_java

        # Force reload of environment
        hash -r

        # Verify installation with a short delay
        sleep 2
        if ! check_java; then
            # Try to source common profile files
            [[ -f /etc/profile ]] && source /etc/profile 2>/dev/null || true
            [[ -f ~/.bashrc ]] && source ~/.bashrc 2>/dev/null || true
            [[ -f ~/.profile ]] && source ~/.profile 2>/dev/null || true

            # Final check
            if ! check_java; then
                error "Java $REQUIRED_JAVA_VERSION installation may have succeeded, but version detection failed."
                error "Please run 'java -version' to verify, then try again."
                error "You may need to restart your terminal or run 'source ~/.bashrc'"
                return 1
            fi
        fi
    fi

    local current_version=$(get_java_version)
    log "Java $current_version is ready!"
    log "Setup complete! Run './mcserver.sh install' to install the server."
}

install() {
    log "Installing Quilt server..."

    # Check Java version first
    if ! check_java; then
        error "Java $REQUIRED_JAVA_VERSION required. Run './mcserver.sh setup' first."
        return 1
    fi

    # Try to load existing configuration
    if ! load_config; then
        # No config file exists, prompt for values
        if ! prompt_minecraft_version; then
            return 1
        fi

        if ! prompt_java_opts; then
            return 1
        fi

        save_config
    else
        # Config exists, ask if user wants to change it
        echo ""
        echo "Current configuration:"
        echo "  Minecraft version: $MINECRAFT_VERSION"
        echo "  Java options: $JAVA_OPTS"
        echo ""
        echo -n "Do you want to change this configuration? (y/N): "
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            if ! prompt_minecraft_version; then
                return 1
            fi

            if ! prompt_java_opts; then
                return 1
            fi

            save_config
        fi
    fi

    # Validate that we have the required values
    if [[ -z "$MINECRAFT_VERSION" ]]; then
        error "Minecraft version not set"
        return 1
    fi

    if [[ -z "$JAVA_OPTS" ]]; then
        error "Java options not set"
        return 1
    fi

    # Create server directory if it doesn't exist
    mkdir -p "$SERVER_DIR"

    # Download installer if not present
    if [[ ! -f "quilt-installer-${QUILT_VERSION}.jar" ]]; then
        log "Downloading Quilt installer..."
        curl -L -o "quilt-installer-${QUILT_VERSION}.jar" "$INSTALLER_URL"
        if [[ $? -ne 0 ]]; then
            error "Failed to download Quilt installer"
            return 1
        fi
    fi

    # Install server
    log "Installing Quilt server for Minecraft $MINECRAFT_VERSION..."
    java -jar "quilt-installer-${QUILT_VERSION}.jar" \
        install server "$MINECRAFT_VERSION" \
        --install-dir="$SERVER_DIR" \
        --download-server

    if [[ $? -ne 0 ]]; then
        error "Quilt server installation failed"
        return 1
    fi

    # Create EULA file
    echo "eula=true" > "$SERVER_DIR/eula.txt"

    log "Quilt server installed successfully!"
    log "Server files are in: $SERVER_DIR"
    log "Use './mcserver.sh start' to start the server."
}

start() {
    log "Starting Minecraft server..."

    # Check Java version
    if ! check_java; then
        error "Java $REQUIRED_JAVA_VERSION required. Run './mcserver.sh setup' first."
        return 1
    fi

    # Load configuration
    if ! load_config; then
        error "No configuration found. Run './mcserver.sh install' first."
        return 1
    fi

    # Check if server is installed
    if [[ ! -f "$SERVER_DIR/quilt-server-launch.jar" ]]; then
        error "Server not installed. Run './mcserver.sh install' first."
        return 1
    fi

    if is_running; then
        warn "Server already running!"
        return 0
    fi

    # Create tmux session and start server
    tmux new-session -d -s "$SESSION" -c "$SERVER_DIR" \
        "java $JAVA_OPTS -jar quilt-server-launch.jar nogui"

    sleep 3

    # Check if it's actually running
    if is_running; then
        log "Server started successfully in tmux session '$SESSION'"
        log "Using Java options: $JAVA_OPTS"
        log "Use './mcserver.sh console' to connect to the server console"
        log "Use './mcserver.sh stop' to stop the server"
    else
        error "Server failed to start. Check logs:"
        if [[ -f "$SERVER_DIR/logs/latest.log" ]]; then
            tail -20 "$SERVER_DIR/logs/latest.log"
        else
            error "No log file found. Try running './mcserver.sh debug' for more info."
        fi
        return 1
    fi
}

stop() {
    log "Stopping server..."

    if ! is_running; then
        warn "Server not running"
        return 0
    fi

    # Send stop command to server
    tmux send-keys -t "$SESSION" "stop" C-m
    log "Stop command sent, waiting for server to shut down..."

    # Wait for server to stop
    for i in {1..30}; do
        if ! is_running; then
            log "Server stopped successfully"
            return 0
        fi
        sleep 1
    done

    warn "Server didn't stop gracefully. Force killing..."
    tmux kill-session -t "$SESSION" 2>/dev/null
    log "Server stopped"
}

console() {
    if is_running; then
        log "Connecting to server console..."
        log "Press Ctrl+B then D to detach from console"
        sleep 1
        tmux attach -t "$SESSION"
    else
        error "Server not running. Use './mcserver.sh start' to start it."
    fi
}

status() {
    if is_running; then
        log "Server is running in tmux session '$SESSION'"
        tmux list-sessions | grep "$SESSION" 2>/dev/null
    else
        log "Server is not running"
    fi
}

debug() {
    log "Debug information:"
    echo ""
    echo "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Architecture: $(uname -m)"
    echo ""
    echo "Java Information:"
    if command -v java >/dev/null 2>&1; then
        java -version
        echo "  Required: Java $REQUIRED_JAVA_VERSION"
        local current_version=$(get_java_version)
        echo "  Detected Version: $current_version"
        if check_java; then
            echo "  Status: ✓ Compatible"
        else
            echo "  Status: ✗ Incompatible (need Java $REQUIRED_JAVA_VERSION)"
        fi
    else
        echo "  Status: ✗ Java not installed"
    fi
    echo ""
    echo "Dependencies:"
    command -v tmux >/dev/null 2>&1 && echo "  tmux: ✓ Installed" || echo "  tmux: ✗ Missing"
    command -v curl >/dev/null 2>&1 && echo "  curl: ✓ Installed" || echo "  curl: ✗ Missing"
    echo ""
    echo "Server Status:"
    if [[ -d "$SERVER_DIR" ]]; then
        echo "  Server directory: ✓ Exists"
        [[ -f "$SERVER_DIR/quilt-server-launch.jar" ]] && echo "  Launcher JAR: ✓ Exists" || echo "  Launcher JAR: ✗ Missing"
        [[ -f "$SERVER_DIR/eula.txt" ]] && echo "  EULA file: ✓ Exists" || echo "  EULA file: ✗ Missing"
    else
        echo "  Server directory: ✗ Missing"
    fi

    if is_running; then
        echo "  Status: ✓ Running"
    else
        echo "  Status: ✗ Not running"
    fi
    echo ""

    if [[ -f "$SERVER_DIR/quilt-server-launch.jar" ]] && check_java; then
        log "Testing server startup (10 second timeout)..."
        if load_config; then
            cd "$SERVER_DIR" || return 1
            timeout 10s java $JAVA_OPTS -jar quilt-server-launch.jar nogui || echo "Server test failed or timed out"
        else
            echo "  Config file: ✗ Missing (run install to create)"
        fi
    fi
}

show_help() {
    echo "Minecraft Quilt Server Manager"
    echo ""
    echo "Usage: $0 {setup|install|start|stop|console|status|debug|config}"
    echo ""
    echo "Commands:"
    echo "  setup   - Install system dependencies and Java $REQUIRED_JAVA_VERSION"
    echo "  install - Download and install Quilt server (prompts for MC version & Java opts)"
    echo "  start   - Start the server in tmux session"
    echo "  stop    - Stop the server gracefully"
    echo "  console - Connect to server console"
    echo "  status  - Show server status"
    echo "  debug   - Show debug information and test server"
    echo "  config  - Show current configuration"
    echo ""
    echo "First time setup:"
    echo "  1. ./mcserver.sh setup"
    echo "  2. ./mcserver.sh install  (will prompt for Minecraft version and Java options)"
    echo "  3. ./mcserver.sh start"
    echo ""
    echo "Daily usage:"
    echo "  ./mcserver.sh start|stop|console"
    echo ""
    echo "The script will prompt you for:"
    echo "  - Minecraft version (e.g., 1.21.6, 1.20.1)"
    echo "  - Java memory options (e.g., -Xms4G -Xmx6G )"
    echo "  - Configuration is saved to mcserver.conf"
}

case "${1:-}" in
    setup)   setup ;;
    install) install ;;
    start)   start ;;
    stop)    stop ;;
    console) console ;;
    status)  status ;;
    debug)   debug ;;
    config)
        if load_config; then
            echo "Current configuration:"
            echo "  Minecraft version: $MINECRAFT_VERSION"
            echo "  Java options: $JAVA_OPTS"
        else
            echo "No configuration found. Run './mcserver.sh install' to create one."
        fi
        ;;
    help|--help|-h) show_help ;;
    *)
        show_help
        exit 1
        ;;
esac
