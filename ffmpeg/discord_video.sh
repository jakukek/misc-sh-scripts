#!/bin/bash

set -euo pipefail

OUTDIR="$HOME/Converted"
mkdir -p "$OUTDIR"

# Safe target under Discord free limit
TARGET_MB="9.5"

# Minimum useful video bitrate
MIN_VBITRATE_K="150"

# Default / max audio bitrate
MAX_ABITRATE_K="128"

for input in "$@"; do
    [ -f "$input" ] || continue

    filename="$(basename "$input")"
    name="${filename%.*}"
    output="$OUTDIR/${name}.mp4"

    echo "Processing: $input"
    echo "Output:     $output"

    # Duration in seconds
    duration=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input")

    # Skip if duration is invalid
    if [ -z "$duration" ]; then
        echo "Could not read duration, skipping."
        echo
        continue
    fi

    # Convert target size to total bitrate (kbit/s)
    # MB -> bits / duration / 1000
    total_bitrate_k=$(awk -v mb="$TARGET_MB" -v dur="$duration" 'BEGIN {
        print int((mb * 1024 * 1024 * 8) / dur / 1000)
    }')

    # Choose audio bitrate
    if [ "$total_bitrate_k" -lt 220 ]; then
        abitrate_k=64
    elif [ "$total_bitrate_k" -lt 320 ]; then
        abitrate_k=96
    else
        abitrate_k="$MAX_ABITRATE_K"
    fi

    # Video bitrate = total - audio - small mux overhead buffer
    vbitrate_k=$(( total_bitrate_k - abitrate_k - 16 ))

    if [ "$vbitrate_k" -lt "$MIN_VBITRATE_K" ]; then
        vbitrate_k="$MIN_VBITRATE_K"
        abitrate_k=64
    fi

    echo "Duration:           ${duration}s"
    echo "Target total rate:  ${total_bitrate_k}k"
    echo "Video bitrate:      ${vbitrate_k}k"
    echo "Audio bitrate:      ${abitrate_k}k"

    passdir=$(mktemp -d)
    passlog="$passdir/ffmpeg"

    # First pass
    ffmpeg -y -i "$input" \
        -map 0:v:0 -map 0:a? \
        -c:v libx264 \
        -b:v "${vbitrate_k}k" \
        -pass 1 \
        -preset medium \
        -pix_fmt yuv420p \
        -movflags +faststart \
        -vf "scale='min(1280,iw)':-2,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
        -c:a aac -b:a "${abitrate_k}k" \
        -f mp4 /dev/null \
        -passlogfile "$passlog"

    # Second pass
    ffmpeg -y -i "$input" \
        -map 0:v:0 -map 0:a? \
        -c:v libx264 \
        -b:v "${vbitrate_k}k" \
        -pass 2 \
        -preset medium \
        -pix_fmt yuv420p \
        -movflags +faststart \
        -vf "scale='min(1280,iw)':-2,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
        -c:a aac -b:a "${abitrate_k}k" \
        "$output" \
        -passlogfile "$passlog"

    rm -f "${passlog}"* 2>/dev/null || true

    final_size=$(stat -c%s "$output" 2>/dev/null || wc -c < "$output")
    final_size_mb=$(awk -v s="$final_size" 'BEGIN { printf "%.2f", s/1024/1024 }')

    echo "Final size: ${final_size_mb} MB"

    if awk -v s="$final_size" 'BEGIN { exit !(s > 10*1024*1024) }'; then
        echo "Warning: file is still over 10 MB."
    else
        echo "OK: under 10 MB."
    fi

    echo
done

echo "All conversions finished."