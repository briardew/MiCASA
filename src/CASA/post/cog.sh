#!/bin/bash

BLURB="MiCASA COG generator"

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
echo "Input  directory: $DIROUT"
echo "Output directory: $DIRCOG"
echo "Collection: $FLXTAG"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

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

for mon in $(seq -f %02g "$MON0" "$MONF"); do
    # Get daily files
    monlen=$(date -d "$year/$mon/1 + 1 month - 1 day" "+%d")
    flist=()
    for day in $(seq -f %02g 01 "$monlen"); do
        # BEWARE: Filenames have underscores that are valid in variable names
        # Being extra cautious about protecting variables with braces in file name
        ff="${FLXTAG}_daily_${year}${mon}${day}.${FEXT}"
        fin="$DIROUT/daily/$year/$mon/$ff"

        [[ -f "$fin" ]] && flist+=("$fin")
    done

    [[ ${#flist[@]} -eq 0 ]] && exit				# Exit if no files found
    mkdir -p "$DIRCOG/daily/$year/$mon"

    # Add monthly file if present
    ff="${FLXTAG}_monthly_${year}${mon}.${FEXT}"
    fin="$DIROUT/monthly/$year/$ff"
    if [[ ${#flist[@]} -eq $monlen ]]; then
        flist+=("$fin")
        mkdir -p "$DIRCOG/monthly/$year"
    fi

    for fin in "${flist[@]}"; do
        ftmp="$DIRCOG/$(basename "$fin" ."$FEXT").tmp.$FEXT"
        cp "$fin" "$ftmp"

        # Scale everything to g C m-2 day-1
        ncap2 -A -h -s 'NPP=float(1e3*60*60*24*NPP)'   "$ftmp"
        ncap2 -A -h -s 'Rh=float(1e3*60*60*24*Rh)'     "$ftmp"
        ncap2 -A -h -s 'ATMC=float(1e3*60*60*24*ATMC)' "$ftmp"
        ncap2 -A -h -s 'FIRE=float(1e3*60*60*24*FIRE)' "$ftmp"
        ncap2 -A -h -s 'FUEL=float(1e3*60*60*24*FUEL)' "$ftmp"
        ncap2 -A -h -s 'NEE=float(1e3*60*60*24*NEE)'   "$ftmp"

        ncatted -O -h -a units,NPP,o,c,'g m-2 day-1'  "$ftmp"
        ncatted -O -h -a units,Rh,o,c,'g m-2 day-1'   "$ftmp"
        ncatted -O -h -a units,ATMC,o,c,'g m-2 day-1' "$ftmp"
        ncatted -O -h -a units,FIRE,o,c,'g m-2 day-1' "$ftmp"
        ncatted -O -h -a units,FUEL,o,c,'g m-2 day-1' "$ftmp"
        ncatted -O -h -a units,NEE,o,c,'g m-2 day-1'  "$ftmp"

        # Create derived variables (NBE)
        ncap2 -A -h -s 'NBE=Rh-NPP-ATMC+FIRE+FUEL' "$ftmp"
        ncatted -O -h -a long_name,NBE,o,c,'Net biospheric exchange' "$ftmp"

        # Sort into daily and monthly folders
        if [[ "$fin" == *"_daily_"* ]]; then
            DIRUSE="$DIRCOG/daily/$year/$mon"
        else
            DIRUSE="$DIRCOG/monthly/$year"
        fi

        # Convert to COG
        for var in NPP Rh FIRE FUEL ATMC NEE NBE; do
            fcog=$(basename "$fin" ".$FEXT").tif
            fcog=${fcog/_flux_/_"$var"_}
            if [[ ! -f "$fcog" || "$FORCE" == true ]]; then
                gdal_translate -q -a_srs EPSG:4326 NETCDF:"$ftmp":"$var" \
                    "$DIRUSE/$fcog" -of COG -co COMPRESS=DEFLATE -a_nodata nan
            fi
        done

        [[ -f "$ftmp" ]] && rm "$ftmp"
    done
done
