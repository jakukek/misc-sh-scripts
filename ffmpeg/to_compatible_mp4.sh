#!/bin/bash

# Output directory
OUTDIR="$HOME/Converted"

# Create directory if it doesn't exist
mkdir -p "$OUTDIR"

for input in "$@"; do
    [ -f "$input" ] || continue

    filename="$(basename "$input")"
    name="${filename%.*}"
    output="$OUTDIR/${name}.mp4"

    echo "Converting: $input"
    echo "Output:     $output"

    ffmpeg -y -i "$input" \
        -map 0:v:0 -map 0:a? \
        -c:v libx264 \
        -preset medium \
        -crf 22 \
        -pix_fmt yuv420p \
        -movflags +faststart \
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
        -c:a aac \
        -b:a 192k \
        "$output"

    echo
done

echo "All conversions finished."