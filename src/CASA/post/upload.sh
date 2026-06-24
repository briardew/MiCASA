#!/usr/bin/env bash

BLURB="MiCASA COG uploader"

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
echo "COG directory: $DOUTCOG"
echo "Collection: $HEADFLX"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

warnings

for mon in $(seq -f %02g "$MON0" "$MONF"); do
    flist=()
    flist+=("$DOUTCOG/daily/$year/$mon"*".tif")
    flist+=("$DOUTCOG/monthly/$year/$mon"*".tif")
    for ff in "${flist[@]}"; do
        fbit=${ff#"$ROOTPUB"/}
        fbit=${fbit/\/cog/}
        fbit=${fbit/MiCASA/delivery\/micasa-carbon-flux}

        echo "Uploading $fbit ..."

        checksum="$(shasum -a 256 "$ff" | cut -f1 -d\ | xxd -r -p | base64)"

        # NB: Uses the AWS profile ghgc
        aws s3api put-object --bucket ghgc-data-store-develop \
            --key "$fbit" --body "$ff" --checksum-sha256 "$checksum" \
            --profile ghgc
    done
done
