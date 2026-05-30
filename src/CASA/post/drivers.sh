#!/bin/bash

BLURB="MiCASA driver post-processor"

# Process settings & arguments
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR"/setup.sh

# Get and check arguments
argparse "$(basename "$0")" "$BLURB" "$@"

# Re-run setup in case $VERSION has changed
. "$POSTDIR"/setup.sh

# Outputs and warnings
# ---
echo "---"
echo "$BLURB" 
echo "---"
echo "Input  directory: $VEGIN"
echo "Output directory: $DIRVEG"
echo "Collection(s): cover, vegind, burn"
echo "Year: $year"

if [[ "$FORCE" == true ]]; then
    echo ""
    echo "WARNING: Overwriting existing files ..."
fi

# Give a chance to abort
if [[ "$BATCH" != true ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

# Build command and arguments
CPCMD="rsync"
CPARGS=("-av" "-R")
$FORCE || CPARGS+=("--ignore-existing")

(
cd "$VEGIN" || exit

"$CPCMD" "${CPARGS[@]}" "cover/*$year*" "$DIRVEG"
"$CPCMD" "${CPARGS[@]}" "vegind/$year"  "$DIRVEG"
"$CPCMD" "${CPARGS[@]}" "burn/$year"    "$DIRVEG"

cd - > /dev/null || exit
)
