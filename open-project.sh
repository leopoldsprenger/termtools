#!/usr/bin/env bash

PROJECTS_DIR="$HOME/projects"

SELECTION=$(find "$PROJECTS_DIR" -mindepth 2 -maxdepth 2 -type d \
    | grep -v '/\.' \
    | sed "s|^$PROJECTS_DIR/||" \
    | fzf --prompt="Select project: ")

if [ -n "$SELECTION" ]; then
    nvim -c "cd $PROJECTS_DIR/$SELECTION"
fi
