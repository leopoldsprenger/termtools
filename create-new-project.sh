#!/usr/bin/env bash
set -e

# Defaults and Constants
PROTOTYPES_DIR="$HOME/Documents/projects/prototypes"
REPO_NAME=""
LANG=""
GITHUB=false
STATUS=""
DESCRIPTION=""

SUPPORTED_LANGS=("python" "py" "cpp" "c++")

log() {
    echo "[*] $1"
}

error() {
    echo "[!] $1" >&2
    exit 1
}

show_help() {
    echo "Usage:"
    echo "  setup.sh <repo_name> [options]"
    echo ""
    echo "Options:"
    echo "  --lang <language>        Project language"
    echo "  --github                 Create GitHub repo"
    echo "  --status <public|private> (requires --github)"
    echo "  --description <text>     (requires --github)"
    echo "  --help                   Show this help"
    echo ""
    echo "Supported languages:"
    printf "  - %s\n" "${SUPPORTED_LANGS[@]}"
}

parse_args() {
    [[ "$1" == "--help" ]] && show_help && exit 0

    REPO_NAME="$1"
    shift 1

    [[ -z "$REPO_NAME" ]] && error "Repository name required"

    local github_seen=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                show_help
                exit 0
                ;;
            --lang)
                [[ -z "$2" ]] && error "--lang requires a value"
                LANG="$2"
                shift 2
                ;;
            --github)
                GITHUB=true
                github_seen=true
                shift
                ;;
            --status)
                if ! $github_seen; then
                    error "--status requires --github and must come after it"
                fi
                STATUS="$2"
                shift 2
                ;;
            --description)
                if ! $github_seen; then
                    error "--description requires --github and must come after it"
                fi
                DESCRIPTION="$2"
                shift 2
                ;;
            *)
                error "Unknown argument: $1"
                ;;
        esac
    done

    log "Parsed args → repo='$REPO_NAME', lang='${LANG:-none}', github=$GITHUB"
}

# Interactive wizard
wizard() {
    log "Starting interactive wizard"

    read -rp "Repository name: " REPO_NAME
    read -rp "Language (enter for empty project): " LANG

    while true; do
        read -rp "Create GitHub repository? [Y/n]: " yn
        case "${yn:-Y}" in
            [Yy]*)
                GITHUB=true
                break
                ;;
            [Nn]*)
                GITHUB=false
                return
                ;;
            *)
                echo "Please answer Y or n."
                ;;
        esac
    done

    echo "Select repository visibility:"
    select STATUS in "public" "private"; do
        [[ -n "$STATUS" ]] && break
        echo "Invalid selection."
    done

    read -rp "Repository description (optional): " DESCRIPTION

    log "Wizard complete → repo='$REPO_NAME', lang='${LANG:-none}', github=$GITHUB"
}

create_cpp_files() {
    log "Scaffolding C++ project"

    mkdir -p src include tests build
    touch README.md .gitignore CMakeLists.txt src/main.cpp

    cat > README.md <<EOF
# $REPO_NAME
EOF

    cat > src/main.cpp <<EOF
#include <iostream>

int main() {
    std::cout << "Project initialized correctly..." << '\n';
    return 0;
}
EOF

    cat > CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.10)
project($REPO_NAME)

set(CMAKE_CXX_STANDARD 23)

add_executable(\${PROJECT_NAME} src/main.cpp)
EOF

    cat > .gitignore <<EOF
build/
cmake-build-*/
*.o
*.exe
*.log
.vscode/
.idea/
.DS_Store
EOF
}

setup_repo() {
    local TARGET_DIR="$PROTOTYPES_DIR/$REPO_NAME"

    log "Creating project at $TARGET_DIR"

    mkdir -p "$PROTOTYPES_DIR"
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR" || exit 1

    git init >/dev/null
    log "Initialized git repository"

    case "$LANG" in
        python|py|Python|Py)
            uv init
            ;;
        cpp|c++|C++|CPP)
            create_cpp_files
            ;;
        *)
            log "No/unknown language → empty project"
            ;;
    esac

    if $GITHUB; then
        log "Creating GitHub repository ($STATUS)"

        gh repo create "$REPO_NAME" \
            --"$STATUS" \
            ${DESCRIPTION:+--description "$DESCRIPTION"} \
            --source=. \
            --remote=origin \
            --push=false
    fi

    log "Done"
}

# Entry point
if [[ $# -gt 0 ]]; then
    parse_args "$@"
else
    wizard
fi

setup_repo
