#!/bin/bash

# -------------------------------
# Convert seconds to HH:MM:SS
seconds_to_hms() {
    printf "%02d:%02d:%02d" $(($1/3600)) $(($1%3600/60)) $(($1%60))
}

# -------------------------------
# Scan current directory for subfolders
DIRS=()
for dir in "$PWD"/*/; do
   DIRS+=("$dir")
done

# Print available folders (basename only)
for i in "${!DIRS[@]}"; do
    echo "$i: $(basename "${DIRS[$i]}")"
done

# -------------------------------
# Read user choice, allow optional --restart
read -p "Choose a CD (append --restart to start over): " choice_input
if [[ "$choice_input" =~ ^([0-9]+)[[:space:]]*--restart ]]; then
    choice="${BASH_REMATCH[1]}"
    RESTART=1
else
    choice="$choice_input"
    RESTART=0
fi

FOLDER="${DIRS[$choice]}"
echo "Selected '$(basename "$FOLDER")'"

STATE_FILE="$FOLDER/mp3_state.txt"
if [[ $RESTART -eq 1 && -f "$STATE_FILE" ]]; then
    echo "Restarting playback from beginning. Deleting previous state."
    rm -f "$STATE_FILE"
fi

# -------------------------------
# Scan all MP3s recursively
MP3S=()
while IFS= read -r file; do
    MP3S+=("$file")
done < <(find "$FOLDER" -type f -iname "*.mp3")

# Sort alphabetically
IFS=$'\n' MP3S=($(printf "%s\n" "${MP3S[@]}" | sort))
unset IFS

# -------------------------------
# Determine starting file
if [ -f "$STATE_FILE" ]; then
    read -r FILE < "$STATE_FILE"
    echo "Resuming $(basename "$FILE")"
else
    FILE="${MP3S[0]}"
    printf "%s\n" "$FILE" > "$STATE_FILE"
fi

# Find index of starting file
for i in "${!MP3S[@]}"; do
    if [[ "${MP3S[$i]}" == "$FILE" ]]; then
        START_IDX=$i
        break
    fi
done

# -------------------------------
# Sequential playback loop
for ((i=START_IDX; i<${#MP3S[@]}; i++)); do
    FILE="${MP3S[$i]}"
    echo "Now playing: $(basename "$FILE")"

    # Start mpv and wait until it finishes
    mpv --no-video "$FILE"

    # Save last played file
    if (( i < ${#MP3S[@]} - 1 )); then
        printf "%s\n" "$FILE" > "$STATE_FILE"
    else
        # Last file finished, remove state
        rm -f "$STATE_FILE"
    fi
done

echo "All files finished. State cleared."