#!/bin/bash

echo "---"
echo "MiCASA COG uploader" 
echo "---"

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

year="$1"
if [[ "$#" -lt 1 || "$year" -lt 0 || 9999 -lt "$year" ]]; then
    echo "ERROR: Please provide a valid 4-digit year as an argument. For example," 1>&2
    echo "    $0 2003" 1>&2
    exit 1
fi
echo "Year: $year"

# Break into years for modularity
ftmp="list.txt.pid$$.tmp"
find "$DIRCOG/daily/$year"   ! -name "$(printf "*\n*")" -name '*.tif' >  "$ftmp"
find "$DIRCOG/monthly/$year" ! -name "$(printf "*\n*")" -name '*.tif' >> "$ftmp"
while IFS= read -r ff; do
    fbit=${ff#$ROOTOUT/}
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
