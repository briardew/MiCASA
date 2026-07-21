#!/usr/bin/env bash

# Be strict about errors
set -euo pipefail

BLURB="MiCASA validation check"

# Process settings & arguments
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR/../../setup.sh"

argparse "$(basename "$0")" "$BLURB" "$@"

DIRCHECK="$DATAIN/v$VER"

# Outputs and warnings
# ---
echo "---"
echo "$BLURB"
echo "---"
echo "Check location: $DIRCHECK"
echo "Collection(s): ${COLSOUT[*]}"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

warnings

# Run
# ---
for mon in $(seq -f %02g "$MON0" "$MONF"); do
    while read -r ff; do
        (
            echo ""
            echo "Checking $ff"
            cd "$(dirname "$ff")" || exit
            shasum -a 256 -c "$ff"
            cd - > /dev/null || exit
        )
    done < <(find "$DIRCHECK" -name "*_${year}${mon}_sha256.txt")
    # A reasonable? compromise to avoid races
    if [[ "$MONF" -eq 12 ]]; then
        while read -r ff; do
            (
                echo "Checking $ff"
                echo ""
                cd "$(dirname "$ff")" || exit
                shasum -a 256 -c "$ff"
                cd - > /dev/null || exit
            )
        done < <(find "$DIRCHECK" -name "*_${year}_sha256.txt")
    fi
done
