#!/bin/bash

echo "---"
echo "MiCASA COG generation" 
echo "---"

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# Simple outputs, warnings, and errors
# Would be nice to have a help file (***FIXME***)
[[ "$REPRO" == true ]] && echo "WARNING: Reprocessing, will overwrite files ..." 1>&2

echo "Input  directory: $DIROUT"
echo "Output directory: $DIRCOG"
echo "Collection: $COLTAG"

year="$1"
if [[ "$#" -lt 1 || "$year" -lt 0 || 9999 -lt "$year" ]]; then
    echo "ERROR: Please provide a valid 4-digit year as an argument. For example," 1>&2
    echo "    $0 2003" 1>&2
    exit 1
fi
echo "Year: $year"

# Give a chance to abort
if [[ "$2" != batch ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

for mon in {01..12}; do
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
            if [[ ! -f "$fcog" || "$REPROCOG" == true ]]; then
                gdal_translate -q -a_srs EPSG:4326 NETCDF:"$ftmp":"$var" \
                    "$DIRUSE/$fcog" -of COG -co COMPRESS=DEFLATE -a_nodata nan
            fi
        done

        [[ -f "$ftmp" ]] && rm "$ftmp"
    done
done
