#!/usr/bin/env bash
set -e
# --- Configuration ---
PROJECTS_DIR="$HOME/projects"
VALID_LANGUAGES=(python node typescript javascript rust c cpp empty)
# --- Helper Functions ---
is_valid_language() {
    local lang="$1"
    for valid in "${VALID_LANGUAGES[@]}"; do
        [ "$lang" = "$valid" ] && return 0
    done
    return 1
}
write_flake_nix() {
    local packages="$1"
    cat << EOF > flake.nix
{
  description = "$PROJECT_NAME dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.\${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            $packages
          ];
        };
      });
}
EOF
}
# --- Wizard: Project Name ---
while true; do
    read -p "Enter project name: " PROJECT_NAME
    if [ -z "$PROJECT_NAME" ]; then
        echo "Invalid project name. A project name is required."
        continue
    fi
    break
done
# --- Wizard: Language ---
while true; do
    read -p "Enter language (enter for empty): " LANGUAGE
    LANGUAGE=$(echo "${LANGUAGE:-empty}" | tr '[:upper:]' '[:lower:]')
    if is_valid_language "$LANGUAGE"; then
        break
    fi
    echo "Invalid language. Valid options: ${VALID_LANGUAGES[*]}"
done
# --- Wizard: Subfolder ---
read -p "Enter folder (default \"prototypes\"): " SUBFOLDER
SUBFOLDER="${SUBFOLDER:-prototypes}"
TARGET_DIR="$PROJECTS_DIR/$SUBFOLDER/$PROJECT_NAME"
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
# --- Declarative NixOS Dev Environment ---
# Writes a per-project flake.nix so system-level tools (interpreters, compilers,
# native libs) are pinned and reproducible. nix-ld handles dynamic linking for
# anything uv/cargo/npm pull in that wasn't built by nix (e.g. manylinux wheels).
if [ "$IS_NIXOS" = true ]; then
    case "$LANGUAGE" in
        python)
            write_flake_nix "python3
            uv"
            ;;
        node|typescript|javascript)
            write_flake_nix "nodejs"
            ;;
        rust)
            write_flake_nix "cargo
            rustc
            rustfmt
            clippy"
            ;;
        c|cpp)
            write_flake_nix "gcc
            gnumake"
            ;;
        *)
            write_flake_nix ""
            ;;
    esac
    echo "use flake" > .envrc
    # Flakes only evaluate files tracked by git, so stage everything now
    # or nix-direnv fails with "not tracked by Git" and falls back
    git add -A
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
