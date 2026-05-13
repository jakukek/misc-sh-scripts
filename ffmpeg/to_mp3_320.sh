#!/bin/bash

# Output directory
OUTDIR="$HOME/Converted"

# Create it if it doesn't exist
mkdir -p "$OUTDIR"

# Convert dropped audio files to MP3 320kbps
for input in "$@"; do
    [ -f "$input" ] || continue

    filename="$(basename "$input")"
    name="${filename%.*}"
    output="$OUTDIR/${name}.mp3"

    echo "Converting: $input"
    echo "Output:     $output"

    ffmpeg -y -i "$input" -vn -c:a libmp3lame -b:a 320k "$output"
done

echo "Done."