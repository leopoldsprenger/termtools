#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
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

# --- Platform Detection Safeguard ---
IS_NIXOS=false
if [ -f /etc/os-release ] && grep -qi "nixos" /etc/os-release; then
    IS_NIXOS=true
fi

NIX_SYSTEM=""
if [ "$IS_NIXOS" = true ]; then
    echo "NixOS environment detected. Determining dynamic system architecture..."
    NIX_SYSTEM=$(nix eval --raw nixpkgs#stdenv.hostPlatform.system)
    echo "Detected System: $NIX_SYSTEM"
else
    echo "Standard OS detected. Skipping Nix flake generation infrastructure."
fi

echo "Creating new project: $PROJECT_NAME (Language: $LANGUAGE)"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# --- Initialize Git ---
git init -q
echo ".direnv/" > .gitignore
echo "result" >> .gitignore
echo ".venv/" >> .gitignore

# --- Initialize Language Core Workspace Structure ---
case "$LANGUAGE" in
    python)
        if command -v uv &> /dev/null; then
            uv init --no-readme --quiet
        else
            mkdir -p src
            touch src/main.py
            echo "# Python project workspace" > README.md
        fi

        if [ "$IS_NIXOS" = true ]; then
            echo "use flake" > .envrc
            cat << EOF > flake.nix
{
  description = "Python project with cross-platform uv support";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "$NIX_SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          uv
          git
        ];

        shellHook = ''
          export LD_LIBRARY_PATH="\${pkgs.stdenv.cc.cc.lib}/lib:\$LD_LIBRARY_PATH"
        '';
      };
    };
}
EOF
        fi
        ;;

    node|typescript|javascript)
        mkdir -p src
        touch src/index.js
        if [ "$IS_NIXOS" = true ]; then
            echo "use flake" > .envrc
            cat << EOF > flake.nix
{
  description = "Node.js Development Environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "$NIX_SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nodejs_20
          nodePackages.npm
          nodePackages.typescript-language-server
        ];
      };
    };
}
EOF
        fi
        ;;

    rust)
        if command -v cargo &> /dev/null; then
            cargo init --quiet
        else
            mkdir -p src
            touch src/main.rs
        fi

        if [ "$IS_NIXOS" = true ]; then
            echo "use flake" > .envrc
            cat << EOF > flake.nix
{
  description = "Rust Development Environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "$NIX_SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          rust-analyzer
        ];
      };
    };
}
EOF
        fi
        ;;

    c|cpp)
        mkdir -p src
        touch src/main.c
        if [ "$IS_NIXOS" = true ]; then
            echo "use flake" > .envrc
            cat << EOF > flake.nix
{
  description = "C/C++ Development Environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "$NIX_SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          gcc
          gnumake
          cmake
          clang-tools
        ];
      };
    };
}
EOF
        fi
        ;;

    empty|*)
        if [ "$IS_NIXOS" = true ]; then
            echo "use flake" > .envrc
            cat << EOF > flake.nix
{
  description = "Minimal Blank Development Environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "$NIX_SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          coreutils
          git
        ];
      };
    };
}
EOF
        fi
        ;;
esac

# --- Evaluate Nix Configurations and Track Shell (NixOS-only step) ---
if [ "$IS_NIXOS" = true ]; then
    git add flake.nix .envrc .gitignore
    nix flake lock --quiet
    direnv allow . &> /dev/null
fi

# --- Remote Repository Prompt Engine ---
echo ""
read -p "Would you like to publish this repository to GitHub? (y/N): " CREATE_REMOTE
if [[ "$CREATE_REMOTE" =~ ^[Yy]$ ]]; then
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI ('gh') is not installed or accessible in current PATH."
        echo "Please install 'gh' onto your target platform configuration framework."
    else
        read -p "Enter remote repository name [$PROJECT_NAME]: " REMOTE_NAME
        REMOTE_NAME="${REMOTE_NAME:-$PROJECT_NAME}"

        read -p "Enter repository description: " REMOTE_DESC

        # Default fallback is now private if you hit enter
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
