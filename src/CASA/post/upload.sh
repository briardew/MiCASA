#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# Get and check arguments
# ---
usage() {
    echo "usage: $(basename "$0") year [options]"
    echo ""
    echo "Upload MiCASA COGs"
    echo ""
    echo "positional arguments:"
    echo "  year        4-digit year to post-process"
    echo ""
    echo "options:"
    echo "  -h, --help  show this help message and exit"
    echo "  --ver VER   version (default: $VERSION)"
    echo "  --batch     operate in batch mode (no user input)"
}

BATCH=false

year="$1"
if [[ "$year" == "--help" || "$year" == "-h" ]]; then
    usage
    exit
elif [[ "$#" -lt 1 || "$year" -lt 1000 || 3000 -lt "$year" ]]; then
    echo "ERROR: Invalid year $year"
    echo ""
    usage
    exit 1
fi

ii=2
while [[ "$ii" -le "$#" ]]; do
    arg="${@:$ii:1}"
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        usage
        exit
    elif [[ "$arg" == "--batch" ]]; then
        BATCH=true
    elif [[ "$arg" == "--ver" ]]; then
        ii=$((ii+1))
        VERSION="${@:$ii:1}"
    else
        echo "ERROR: Invalid $ii-th argument $arg"
        echo ""
        usage
        exit 1
    fi
    ii=$((ii+1))
done

# Re-run setup in case $VERSION has changed
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# Outputs and warnings
# ---
echo "---"
echo "MiCASA COG uploader" 
echo "---"

echo "COG directory: $DIRCOG"
echo "Collection: $FLXTAG"
echo "Year: $year"

# Give a chance to abort
if [[ "$BATCH" != true ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

# Do it
# ---
ftmp="list.txt.pid$$.tmp"
find "$DIRCOG/daily/$year"   ! -name "$(printf "*\n*")" -name '*.tif' >  "$ftmp"
find "$DIRCOG/monthly/$year" ! -name "$(printf "*\n*")" -name '*.tif' >> "$ftmp"
while IFS= read -r ff; do
    fbit=${ff#$ROOTPUB/}
    fbit=${fbit/\/cog/}

    checksum="$(shasum -a 256 "$ff" | cut -f1 -d\ | xxd -r -p | base64)"

    aws s3api put-object --bucket ghgc-data-store-dev \
        --key "$fbit" --body "$ff" --checksum-sha256 "$checksum"
done < "$ftmp"
rm "$ftmp"

# Keeping just in case
#   aws s3 cp "$DIRCOG/monthly/$year" \
#       "s3://ghgc-data-store-dev/MiCASA/v$VERSION/monthly/$year/" \
#       --recursive --exclude "*" --include "*.tif"
#   aws s3 cp "$DIRCOG/daily/$year" \
#       "s3://ghgc-data-store-dev/MiCASA/v$VERSION/daily/$year/" \
#       --recursive --exclude "*" --include "*.tif"
