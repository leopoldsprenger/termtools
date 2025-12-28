#!/usr/bin/env bash

############################
# Defaults (global outputs)
############################
REPO_NAME=""
LANG=""
GITHUB=false
STATUS=""
DESCRIPTION=""

############################
# CLI argument parser
############################
parse_args() {
    REPO_NAME="$1"
    LANG="$2"
    shift 2

    GITHUB=false
    STATUS=""
    DESCRIPTION=""

    local github_seen=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --github)
                GITHUB=true
                github_seen=true
                shift
                ;;
            --status)
                if ! $github_seen; then
                    echo "Error: --status requires --github and must come after it" >&2
                    exit 1
                fi
                STATUS="$2"
                shift 2
                ;;
            --description)
                if ! $github_seen; then
                    echo "Error: --description requires --github and must come after it" >&2
                    exit 1
                fi
                DESCRIPTION="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1" >&2
                exit 1
                ;;
        esac
    done
}

############################
# Interactive wizard
############################
wizard() {
    read -rp "Repository name: " REPO_NAME
    read -rp "Language: " LANG

    # GitHub Y/n choice
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

    # Arrow-key selection for repo visibility
    echo "Select repository visibility:"
    select STATUS in "public" "private"; do
        [[ -n "$STATUS" ]] && break
        echo "Invalid selection."
    done

    read -rp "Repository description (optional): " DESCRIPTION
}

############################
# Create new python venv
############################
create_py_venv() {
    python3 -m venv .venv

    # system-specific activation
    case "$OSTYPE" in
        linux*|darwin*)
            source .venv/bin/activate
            ;;
        msys*|cygwin*|win32*)
            source .venv/Scripts/activate
            ;;
        *)
            echo "Warning: could not auto-activate venv on OSTYPE='$OSTYPE'"
            ;;
    esac
}

############################
# Create python specific files
############################
create_py_files() {
    mkdir -p src tests

    touch README.md .gitignore src/main.py

    cat > README.md <<EOF
# $REPO_NAME
EOF
    
    cat > src/main.py <<EOF
def main():
    print("Project initialized correctly...")

if __name__ == "__main__":
    main()
EOF

    cat > .gitignore <<EOF
# .gitignore

# Ignore environment files
.env

# Ignore IDE/project-specific files
.ropeproject/

# Ignore Python bytecode
__pycache__/
*.pyc
.pytest_cache/

# Ignore virtual environment
venv/
.venv/
pyenv/

# Ignore logs
*.log

# Ignore IDE configurations (e.g., VS Code, PyCharm)
.vscode/
.idea/

# Ignore macOS system files
.DS_Store
EOF
}

############################
# Create C++ files
############################
create_cpp_files() {
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

# Add source files
add_executable(\${PROJECT_NAME} src/main.cpp)
EOF

    cat > .gitignore <<EOF
# Build directories
build/
cmake-build-*/

# Compiled objects and binaries
*.o
*.obj
*.out
*.exe
*.dll
*.so
*.dylib
a.out

# CMake files
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
compile_commands.json

# Logs
*.log

# IDE / editor files
.vscode/
.idea/

# macOS
.DS_Store

# Windows
Thumbs.db
EOF
}

############################
# Setup the repository
############################
setup_repo() {
    # create repo directory and init git
    mkdir -p "$REPO_NAME"
    cd "$REPO_NAME" || exit 1

    git init

    ################################
    # Create project files
    ################################
    case "$LANG" in
        python|py|Python|Py)
            create_py_venv
            create_py_files
            ;;
        cpp|c++|C++|CPP)
            create_cpp_files
            ;;
        *)
            echo "Error: language '$LANG' not supported"
            exit 1
            ;;
    esac

    ################################
    # GitHub repo creation (optional)
    ################################
    if $GITHUB; then
        gh repo create "$REPO_NAME" \
            --"$STATUS" \
            ${DESCRIPTION:+--description "$DESCRIPTION"} \
            --source=. \
            --remote=origin \
            --push=false
    fi

    ################################
    # Initial commit and push
    ################################
    git add .
    git commit -m "Initial commit"

    if $GITHUB; then
        git push -u origin main 2>/dev/null || git push -u origin master
    fi
}

############################
# Entry point
############################
if [[ $# -gt 0 ]]; then
    parse_args "$@"
else
    wizard
fi

setup_repo