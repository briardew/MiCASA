#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# Get and check arguments
# ---
usage() {
    echo "usage: $(basename "$0") year [options]"
    echo ""
    echo "Create MiCASA COGs"
    echo ""
    echo "positional arguments:"
    echo "  year        4-digit year to post-process"
    echo ""
    echo "options:"
    echo "  -h, --help  show this help message and exit"
    echo "  --mon MON   only process month MON"
    echo "  --ver VER   version (default: $VERSION)"
    echo "  --repro     reprocess/overwrite (default: false)"
    echo "  --batch     operate in batch mode (no user input)"
}

# Defaults
MON0=01
MONF=12
REPRO=false
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
    elif [[ "$arg" == "--mon" ]]; then
        ii=$((ii+1))
        mon="${@:$ii:1}"
        if [[ "$mon" -lt 1 || 12 -lt "$mon" ]]; then
            echo "ERROR: Invalid month $mon"
            echo ""
            usage
            exit 1
        fi
        MON0=$(printf %02d "$mon")
        MONF=$(printf %02d "$mon")
    elif [[ "$arg" == "--ver" ]]; then
        ii=$((ii+1))
        VERSION="${@:$ii:1}"
    elif [[ "$arg" == "--repro" ]]; then
        REPRO=true
    elif [[ "$arg" == "--batch" ]]; then
        BATCH=true
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
echo "MiCASA COG generation" 
echo "---"
echo "Input  directory: $DIROUT"
echo "Output directory: $DIRCOG"
echo "Collection: $COLTAG"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

if [[ "$REPRO" == true ]]; then
    echo ""
    echo "WARNING: Reprocessing, will overwrite files ..."
fi

# Give a chance to abort
if [[ "$BATCH" != true ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

for mon in $(seq -f "%02g" $MON0 $MONF); do
    # Get daily files
    monlen=$(date -d "$year/$mon/1 + 1 month - 1 day" "+%d")
    flist=()
    for day in $(seq -w 01 "$monlen"); do
        ff="${COLTAG}_daily_$year$mon$day.nc"
        fout="$DIROUT/daily/$year/$mon/$ff"

        [[ -f "$fout" ]] && flist+=("$fout")
    done

    [[ ${#flist[@]} -eq 0 ]] && exit				# Exit if no files found
    mkdir -p "$DIRCOG/daily/$year/$mon"

    # Add monthly file if present
    ff="${COLTAG}_monthly_$year$mon.nc"
    fout="$DIROUT/monthly/$year/$ff"
    if [[ ${#flist[@]} -eq $monlen ]]; then
        flist+=("$fout")
        mkdir -p "$DIRCOG/monthly/$year"
    fi

    for fin in "${flist[@]}"; do
        # Create derived variables (NEE & NBE)
        ftmp="$DIRCOG/$(basename "$fin" .nc).tmp.nc"

        ncap2 -O -h -s 'NEE=Rh-NPP-ATMC;NBE=Rh-NPP-ATMC+FIRE+FUEL' "$fin" "$ftmp"
        ncatted -O -h -a long_name,NEE,o,c,'Net ecosystem exchange'  "$ftmp"
        ncatted -O -h -a long_name,NBE,o,c,'Net biospheric exchange' "$ftmp"

        # Sort into daily and monthly folders
        if [[ "$fin" == *"_daily_"* ]]; then
            DIRUSE="$DIRCOG/daily/$year/$mon"
        else
            DIRUSE="$DIRCOG/monthly/$year"
        fi

        # Convert to COG
        for var in NPP Rh FIRE FUEL ATMC NEE NBE; do
            fcog=$(basename "$fin" .nc).tif
            fcog=${fcog/_flux_/_"$var"_}
            if [[ ! -f "$fcog" || "$REPRO" == true ]]; then
                gdal_translate -q -a_srs EPSG:4326 NETCDF:"$ftmp":"$var" \
                    "$DIRUSE/$fcog" -of COG -co COMPRESS=DEFLATE -a_nodata nan
            fi
        done

        [[ -f "$ftmp" ]] && rm "$ftmp"
    done
done
