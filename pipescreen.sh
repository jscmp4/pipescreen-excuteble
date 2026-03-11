#!/usr/bin/env bash
set -euo pipefail

# ── Config ───────────────────────────────────────────────────
CONFIG_FILE="${HOME}/.pipescreen.conf"
DEFAULT_PORT=3030

# Load saved config
DATA_DIR=""
PORT="$DEFAULT_PORT"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

API="http://localhost:${PORT}"

# ── Detect platform ─────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) PLATFORM="windows" ;;
    Darwin)                          PLATFORM="macos"   ;;
    Linux)                           PLATFORM="linux"   ;;
    *)                               PLATFORM="unknown" ;;
esac

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Helpers ──────────────────────────────────────────────────
print_header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║          PIPESCREEN                  ║"
    echo "  ║   Screen + Life Timeline Recorder    ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${DIM}Platform: ${PLATFORM}  |  API: ${API}${RESET}"
    if [[ -n "$DATA_DIR" ]]; then
        echo -e "  ${DIM}Data dir: ${DATA_DIR}${RESET}"
    fi
    echo ""
}

is_running() {
    curl -s --max-time 2 "${API}/health" > /dev/null 2>&1
}

print_status() {
    if is_running; then
        echo -e "  Status: ${GREEN}● Recording${RESET}"
    else
        echo -e "  Status: ${RED}● Stopped${RESET}"
    fi
    echo ""
}

find_screenpipe() {
    if command -v screenpipe &> /dev/null; then
        echo "screenpipe"
        return
    fi
    # Windows npm global install path
    local npm_bin="${APPDATA:-}/npm/node_modules/screenpipe/node_modules/@screenpipe/cli-win32-x64/bin/screenpipe.exe"
    if [[ -f "$npm_bin" ]]; then
        echo "$npm_bin"
        return
    fi
    echo ""
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
DATA_DIR="${DATA_DIR}"
PORT="${PORT}"
EOF
}

# ── Actions ──────────────────────────────────────────────────
do_start() {
    if is_running; then
        echo -e "  ${YELLOW}Already running.${RESET}"
        sleep 1
        return
    fi

    local bin
    bin="$(find_screenpipe)"
    if [[ -z "$bin" ]]; then
        echo -e "  ${RED}screenpipe not found. Install first (option 6).${RESET}"
        sleep 2
        return
    fi

    local args=("record" "--port" "$PORT")
    if [[ -n "$DATA_DIR" ]]; then
        args+=("--data-dir" "$DATA_DIR")
    fi

    echo -e "  ${CYAN}Starting screenpipe...${RESET}"
    "$bin" "${args[@]}" > /dev/null 2>&1 &
    local pid=$!
    echo -e "  ${DIM}PID: ${pid}${RESET}"

    # Wait for health
    for i in $(seq 1 30); do
        if is_running; then
            echo -e "  ${GREEN}Started successfully!${RESET}"
            sleep 1
            return
        fi
        sleep 2
    done
    echo -e "  ${YELLOW}Started but health check not responding yet.${RESET}"
    echo -e "  ${DIM}It may still be initializing. Check status in a moment.${RESET}"
    sleep 2
}

do_stop() {
    if ! is_running; then
        echo -e "  ${YELLOW}Not running.${RESET}"
        sleep 1
        return
    fi

    echo -e "  ${CYAN}Stopping screenpipe...${RESET}"
    if [[ "$PLATFORM" == "windows" ]]; then
        taskkill //F //IM screenpipe.exe > /dev/null 2>&1 || true
    else
        pkill -f "screenpipe record" 2>/dev/null || true
    fi
    sleep 1
    if is_running; then
        echo -e "  ${RED}Failed to stop. Try manually.${RESET}"
    else
        echo -e "  ${GREEN}Stopped.${RESET}"
    fi
    sleep 1
}

do_search() {
    if ! is_running; then
        echo -e "  ${RED}Not running. Start first.${RESET}"
        sleep 2
        return
    fi

    echo -ne "  ${BOLD}Search query (empty = recent):${RESET} "
    read -r query
    echo -ne "  ${BOLD}Limit [5]:${RESET} "
    read -r limit
    limit="${limit:-5}"

    local url="${API}/search?limit=${limit}"
    if [[ -n "$query" ]]; then
        url="${url}&q=$(printf '%s' "$query" | sed 's/ /%20/g')"
    fi

    echo ""
    echo -e "  ${DIM}GET ${url}${RESET}"
    echo ""
    curl -s "$url" | python3 -m json.tool 2>/dev/null || curl -s "$url"
    echo ""
    echo -e "  ${DIM}Press Enter to continue...${RESET}"
    read -r
}

do_config() {
    echo -e "  ${BOLD}Current config:${RESET}"
    echo -e "  Data dir: ${DATA_DIR:-"(default: ~/.screenpipe)"}"
    echo -e "  Port:     ${PORT}"
    echo ""
    echo -ne "  ${BOLD}New data dir (Enter to keep, 'reset' for default):${RESET} "
    read -r new_dir
    if [[ "$new_dir" == "reset" ]]; then
        DATA_DIR=""
        echo -e "  ${GREEN}Reset to default.${RESET}"
    elif [[ -n "$new_dir" ]]; then
        mkdir -p "$new_dir" 2>/dev/null || true
        DATA_DIR="$new_dir"
        echo -e "  ${GREEN}Set to: ${DATA_DIR}${RESET}"
    fi

    echo -ne "  ${BOLD}New port (Enter to keep) [${PORT}]:${RESET} "
    read -r new_port
    if [[ -n "$new_port" ]]; then
        PORT="$new_port"
        API="http://localhost:${PORT}"
        echo -e "  ${GREEN}Port set to: ${PORT}${RESET}"
    fi

    save_config
    echo -e "  ${DIM}Config saved to ${CONFIG_FILE}${RESET}"
    sleep 1
}

do_data_info() {
    local data_path="${DATA_DIR:-$HOME/.screenpipe}"
    echo -e "  ${BOLD}Data location:${RESET} ${data_path}"
    echo ""
    if [[ -d "$data_path" ]]; then
        local db_size="0"
        local data_size="0"
        if [[ -f "$data_path/db.sqlite" ]]; then
            if [[ "$PLATFORM" == "windows" ]]; then
                db_size=$(wc -c < "$data_path/db.sqlite" 2>/dev/null | tr -d ' ')
            else
                db_size=$(stat -f%z "$data_path/db.sqlite" 2>/dev/null || stat -c%s "$data_path/db.sqlite" 2>/dev/null || echo "0")
            fi
            db_size=$(( db_size / 1024 / 1024 ))
        fi
        echo -e "  ${DIM}db.sqlite:  ~${db_size} MB${RESET}"
        if [[ -d "$data_path/data" ]]; then
            local file_count
            file_count=$(find "$data_path/data" -type f 2>/dev/null | wc -l | tr -d ' ')
            echo -e "  ${DIM}Media files: ${file_count} files${RESET}"
        fi
    else
        echo -e "  ${YELLOW}Directory does not exist yet. Start recording first.${RESET}"
    fi
    echo ""
    echo -e "  ${DIM}Press Enter to continue...${RESET}"
    read -r
}

do_install() {
    local bin
    bin="$(find_screenpipe)"
    if [[ -n "$bin" ]]; then
        echo -e "  ${GREEN}Already installed: ${bin}${RESET}"
        "$bin" --version 2>/dev/null || true
        sleep 2
        return
    fi

    echo -e "  ${CYAN}Installing screenpipe...${RESET}"
    if [[ "$PLATFORM" == "macos" || "$PLATFORM" == "linux" ]]; then
        curl -fsSL https://screenpi.pe/cli | sh
    elif [[ "$PLATFORM" == "windows" ]]; then
        npm install -g screenpipe@latest --ignore-scripts
    fi

    bin="$(find_screenpipe)"
    if [[ -n "$bin" ]]; then
        echo -e "  ${GREEN}Installed!${RESET}"
    else
        echo -e "  ${RED}Installation may need a terminal restart.${RESET}"
    fi
    sleep 2
}

# ── Quick start (no menu, just record) ──────────────────────
if [[ "${1:-}" == "--quick" || "${1:-}" == "-q" ]]; then
    bin="$(find_screenpipe)"
    if [[ -z "$bin" ]]; then
        echo "screenpipe not found. Run without --quick to install."
        exit 1
    fi
    args=("record" "--port" "$PORT")
    [[ -n "$DATA_DIR" ]] && args+=("--data-dir" "$DATA_DIR")
    echo "Starting screenpipe (quick mode)..."
    exec "$bin" "${args[@]}"
fi

# ── Main menu loop ──────────────────────────────────────────
while true; do
    print_header
    print_status

    echo -e "  ${BOLD}[1]${RESET} Start recording"
    echo -e "  ${BOLD}[2]${RESET} Stop recording"
    echo -e "  ${BOLD}[3]${RESET} Search screen history"
    echo -e "  ${BOLD}[4]${RESET} View data info"
    echo -e "  ${BOLD}[5]${RESET} Settings (data dir, port)"
    echo -e "  ${BOLD}[6]${RESET} Install / update screenpipe"
    echo -e "  ${BOLD}[q]${RESET} Quit"
    echo ""
    echo -ne "  ${BOLD}> ${RESET}"
    read -r choice

    case "$choice" in
        1) do_start   ;;
        2) do_stop    ;;
        3) do_search  ;;
        4) do_data_info ;;
        5) do_config  ;;
        6) do_install ;;
        q|Q) echo -e "  ${DIM}Bye!${RESET}"; exit 0 ;;
        *) ;;
    esac
done
