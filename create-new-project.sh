#!/usr/bin/env bash

set -e

# --- Configuration ---
PROJECTS_DIR="$HOME/Projects" # Modify this to match your local project directory path

# --- Helper Functions ---
print_usage() {
    echo "Usage: $(basename "$0") <project_name> [language]"
    echo "Available languages: python, node, rust, c, empty"
    exit 1
}

# --- Argument Validation ---
if [ -z "$1" ]; then
    echo "Error: Missing project name."
    print_usage
fi

PROJECT_NAME="$1"
LANGUAGE=$(echo "${2:-empty}" | tr '[:upper:]' '[:lower:]')
TARGET_DIR="$PROJECTS_DIR/$PROJECT_NAME"

if [ -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' already exists."
    exit 1
fi

# --- Platform Detection ---
IS_NIXOS=false
if [ -f /etc/os-release ] && grep -qi "nixos" /etc/os-release; then
    IS_NIXOS=true
fi

echo "Creating new project: $PROJECT_NAME (Language: $LANGUAGE)"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# --- Initialize Git ---
git init -q

# --- Initialize Language Core Workspace Structure ---
case "$LANGUAGE" in
    python)
        # Natively bootstraps with uv across all systems
        if command -v uv &> /dev/null; then
            uv init --no-readme --quiet
        else
            mkdir -p src
            touch src/main.py
            echo "# Python project workspace" > README.md
        fi
        ;;

    node|typescript|javascript)
        mkdir -p src
        touch src/index.js
        if command -v npm &> /dev/null; then
            npm init -y > /dev/null
        fi
        ;;

    rust)
        if command -v cargo &> /dev/null; then
            cargo init --quiet
        else
            mkdir -p src
            touch src/main.rs
        fi
        ;;

    c|cpp)
        mkdir -p src
        touch src/main.c
        cat << EOF > Makefile
default:
	gcc src/main.c -o result
EOF
        ;;

    empty|*)
        touch .keep
        ;;
esac

# --- Optional NixOS Direnv Layout Hook ---
# Thanks to global nix-ld, we only need to hook into the shell layout engine
if [ "$IS_NIXOS" = true ]; then
    case "$LANGUAGE" in
        python)
            echo "layout virtualenv" > .envrc
            ;;
        node|typescript|javascript)
            echo "layout node" > .envrc
            ;;
        *)
            # Fallback layout trigger if desired
            touch .envrc
            ;;
    esac
    # Allows direnv silently without blocking script execution
    direnv allow . &> /dev/null || true
fi

# --- Remote Repository Prompt Engine ---
echo ""
read -p "Would you like to publish this repository to GitHub? (y/N): " CREATE_REMOTE
if [[ "$CREATE_REMOTE" =~ ^[Yy]$ ]]; then
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI ('gh') is not installed or accessible in current PATH."
        echo "Please verify that 'pkgs.gh' is configured in your system suite."
    else
        read -p "Enter remote repository name [$PROJECT_NAME]: " REMOTE_NAME
        REMOTE_NAME="${REMOTE_NAME:-$PROJECT_NAME}"

        read -p "Enter repository description: " REMOTE_DESC

        # Defaults to private if you press Enter
        read -p "Make repository public? (y/N): " IS_PUBLIC
        VISIBILITY="--private"
        if [[ "$IS_PUBLIC" =~ ^[Yy]$ ]]; then
            VISIBILITY="--public"
        fi

        echo "Provisioning remote GitHub repository..."
        git add -A
        git commit -m "Initial commit" --quiet
        
        gh repo create "$REMOTE_NAME" $VISIBILITY -d "$REMOTE_DESC" --source=. --remote=origin --push
        echo "Remote repository tracking successfully established."
    fi
fi

echo "Project '$PROJECT_NAME' successfully initialized at: $TARGET_DIR"
