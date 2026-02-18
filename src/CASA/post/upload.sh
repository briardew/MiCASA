#!/bin/bash

BLURB="MiCASA COG uploader"

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
echo "COG directory: $DIRCOG"
echo "Collection: $FLXTAG"
echo "Year: $year"

# Give a chance to abort
if [[ "$BATCH" != true ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

while IFS= read -r -d '' ff; do
    fbit=${ff#$ROOTPUB/}
    fbit=${fbit/\/cog/}
    fbit=${fbit/MiCASA/delivery\/micasa-carbon-flux}

    echo "Uploading $fbit ..."

    checksum="$(shasum -a 256 "$ff" | cut -f1 -d\ | xxd -r -p | base64)"

    # NB: Uses the AWS profile ghgc
    aws s3api put-object --bucket ghgc-data-store-develop \
        --key "$fbit" --body "$ff" --checksum-sha256 "$checksum" \
        --profile ghgc
done < <(find "$DIRCOG/daily/$year" "$DIRCOG/monthly/$year" \
    -name '*.tif' -print0)
