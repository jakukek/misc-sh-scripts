#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BANKREV="$SCRIPT_DIR/BankRev.exe"
CFGCONVERT="$SCRIPT_DIR/CfgConvert.exe"
BASE_OUT_DIR="$(pwd)/out"

if [ ! -f "$BANKREV" ]; then
    echo "Error: BankRev.exe not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$CFGCONVERT" ]; then
    echo "Error: CfgConvert.exe not found in $SCRIPT_DIR"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage:"
    echo "  $0 file.pbo"
    echo "  $0 file1.pbo file2.pbo"
    echo "  $0 folder/"
    echo "  $0 folder1/ folder2/"
    exit 1
fi

mkdir -p "$BASE_OUT_DIR"

convert_bin() {
    local input="$1"
    local bin_file
    local cpp_file
    local win_bin
    local win_cpp

    bin_file="$(realpath "$input")"
    cpp_file="${bin_file%.*}.cpp"

    echo "  Converting:"
    echo "    $bin_file"
    echo "    -> $cpp_file"

    win_bin="$(winepath -w "$bin_file")"
    win_cpp="$(winepath -w "$cpp_file")"

    wine "$CFGCONVERT" -txt -dst "$win_cpp" "$win_bin"

    if [ -s "$cpp_file" ]; then
        echo "    SUCCESS"
        rm -f "$bin_file"
        echo "    Deleted: $bin_file"
    else
        echo "    FAILED (empty or missing output)"
        rm -f "$cpp_file" 2>/dev/null
    fi

    echo
}

process_pbo() {
    local input="$1"
    local pbo_path
    local pbo_name
    local out_dir
    local win_pbo
    local win_out

    pbo_path="$(realpath "$input")"
    pbo_name="$(basename "$pbo_path" .pbo)"
    out_dir="$BASE_OUT_DIR/$pbo_name"

    mkdir -p "$out_dir"

    win_pbo="$(winepath -w "$pbo_path")"
    win_out="$(winepath -w "$out_dir")"

    echo "Unpacking: $pbo_path"
    echo "To:        $out_dir"

    wine "$BANKREV" "$win_pbo" "$win_out"

    chmod -R 755 "$out_dir" 2>/dev/null

    echo

    local found_bins=0
    while IFS= read -r -d '' bin_file; do
        found_bins=1
        convert_bin "$bin_file"
    done < <(find "$out_dir" -type f -iname "config.bin" -print0 | sort -z)

    if [ "$found_bins" -eq 0 ]; then
        echo "  No config.bin files found in: $out_dir"
        echo
    fi
}

for arg in "$@"; do
    if [ -d "$arg" ]; then
        found_any=0
        while IFS= read -r -d '' pbo_file; do
            found_any=1
            process_pbo "$pbo_file"
        done < <(find "$arg" -maxdepth 1 -type f -iname "*.pbo" -print0 | sort -z)

        if [ "$found_any" -eq 0 ]; then
            echo "No .pbo files found in folder: $arg"
            echo
        fi

    elif [ -f "$arg" ]; then
        case "${arg,,}" in
            *.pbo)
                process_pbo "$arg"
                ;;
            *)
                echo "Skipping non-PBO file: $arg"
                echo
                ;;
        esac
    else
        echo "Skipping missing path: $arg"
        echo
    fi
done

echo "All done."
