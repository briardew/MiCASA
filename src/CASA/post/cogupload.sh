#!/usr/bin/env bash

BLURB="MiCASA COG uploader"
S3BUCKET="ghgc-data-store-develop"

# Process settings & arguments
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR"/setup.sh

argparse "$(basename "$0")" "$BLURB" "$@"

# Outputs and warnings
# ---
echo "---"
echo "$BLURB"
echo "---"
echo "Input location: $DOUTCOG"
echo "Output location: $S3BUCKET"
echo "Collection: $HEADFLX"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

warnings

echo ""

# Run
# ---
for mon in $(seq -f %02g "$MON0" "$MONF"); do
    flist=()
    flist+=("$DOUTCOG/daily/$year/$mon"*".tif")
    flist+=("$DOUTCOG/monthly/$year/$mon"*".tif")
    for ff in "${flist[@]}"; do
        fbit=${ff#"$ROOTOUT"/}
        fbit=${fbit/\/cog/}
        fbit=${fbit/MiCASA/delivery\/micasa-carbon-flux}

        echo "Uploading $fbit ..."

        checksum="$(shasum -a 256 "$ff" | cut -f1 -d\ | xxd -r -p | base64)"

        # NB: Uses the AWS profile ghgc
        aws s3api put-object --bucket "$S3BUCKET" --key "$fbit" --body "$ff" \
            --checksum-sha256 "$checksum" --profile ghgc
    done
done
