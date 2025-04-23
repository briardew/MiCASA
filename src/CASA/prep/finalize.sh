#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

DIRIN=$MIDIR/data/v$VERSION/drivers
DIROUT=/css/gmao/geos_carb/pub/MiCASA/v$VERSION/drivers

# Get and check arguments
# ---
usage() {
    echo "usage: $(basename "$0") year [options]"
    echo ""
    echo "Finalize MiCASA drivers"
    echo ""
    echo "positional arguments:"
    echo "  year        4-digit year to post-process"
    echo ""
    echo "options:"
    echo "  -h, --help  show this help message and exit"
    echo "  --mon MON   only process month MON"
    echo "  --ver VER   version (default: $VERSION)"
    echo "  --repro     reprocess/overwrite (default: false)"
    echo "  --deflate   reprocess/overwrite (default: false)"
    echo "  --batch     operate in batch mode (no user input)"
}

# Defaults
MON0=01
MONF=12
REPRO=false
DEFLATE=false
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
    elif [[ "$arg" == "--deflate" ]]; then
        DEFLATE=true
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
echo "MiCASA driver finalization" 
echo "---"
echo "Input  directory: $DIRIN"
echo "Output directory: $DIROUT"
echo "Deflate: $DEFLATE"
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

cpcmd() {
    if [[ "$DEFLATE" == true ]]; then
        # A little extra in case $1 == $2
        ftmp="${2%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$1" "$ftmp"
        mv "$ftmp" "$2"
    else
        cp "$1" "$2"
    fi
}

exit

# COVER
#==============================================================================
ff="MiCASA_v${VERSION}_cover_${RESTAG}_yearly_$year.$FEXT"
fin="$DIRIN/cover/$ff"
fout="$DIROUT/cover/$ff"

if [[ -f "$fin" ]]; then
    if [[ ! -f "$fout" || "$REPRO" == true ]]; then
        mkdir -p "$DIROUT/cover"
        cpcmd "$fin" "$fout"
    fi
fi

for mon in $(seq -f "%02g" $MON0 $MONF); do
    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")

#   VEGIND
#==============================================================================
    ndays=0
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="MiCASA_v${VERSION}_vegind_${RESTAG}_daily_$year$mon$day.$FEXT"
        fin="$DIRIN/vegind/$year/$ff"
        fout="$DIROUT/vegind/$year/$ff"

        if [[ -f "$fin" ]]; then
            ndays=$((ndays + 1))
            if [[ ! -f "$fout" || "$REPRO" == true ]]; then
                nproc=$((nproc + 1))
                mkdir -p "$DIROUT/vegind/$year"
                cpcmd "$fin" "$fout"

                ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
                ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
                ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
                ncatted -O -h -a title,global,o,c,"MiCASA Daily NDVI fPAR Vegetation Indices $RESLONG v$VERSION" "$fout"
                ncatted -O -h -a LongName,global,o,c,"MiCASA Daily NDVI fPAR Vegetation Indices $RESLONG" "$fout"
                ncatted -O -h -a ShortName,global,o,c,'MICASA_VEGIND_D' "$fout"
                ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
                ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
                ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
                ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#               ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#               ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
#               ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$ff" "$fout"
#               ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$fchk" "$fout"
                ncatted -O -h -a ReadMeURL,global,o,c,"$SERVE/$HEADDOC/MiCASA_README.pdf" "$fout"
                ncatted -O -h -a RangeBeginningDate,global,o,c,"$year-$mon-$day" "$fout"
                ncatted -O -h -a RangeBeginningTime,global,o,c,"00:00:00.000000" "$fout"
                ncatted -O -h -a RangeEndingDate,global,o,c,"$year-$mon-$day" "$fout"
                ncatted -O -h -a RangeEndingTime,global,o,c,"23:59:59.999999" "$fout"
                ncatted -O -h -a NorthernmostLatiude,global,o,c,'90.0' "$fout"
                ncatted -O -h -a WesternmostLongitude,global,o,c,'-180.0' "$fout"
                ncatted -O -h -a SouthernmostLatitude,global,o,c,'-90.0' "$fout"
                ncatted -O -h -a EasternmostLongitude,global,o,c,'180.0' "$fout"
                ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"

                # Update checksum
                (
                cd "$DIROUT/vegind/$year" || exit
                shasum -a 256 "$ff" >> "$fchk"
                cd - > /dev/null || exit
                )
            fi
        fi
    done

    echo "$year/$mon: Processed $nproc daily files out of $ndays"

    ff="MiCASA_v${VERSION}_vegind_${RESTAG}_monthly_$year$mon.$FEXT"
    fin="$DIRIN/vegind/$year/$ff"
    fout="$DIROUT/vegind/$year/$ff"

    if [[ -f "$fin" ]]; then
        ndays=$((ndays + 1))
        if [[ ! -f "$fout" || "$REPRO" == true ]]; then
            nproc=$((nproc + 1))
            mkdir -p "$DIROUT/vegind/$year"
            cpcmd "$fin" "$fout"

            ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
            ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
            ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
            ncatted -O -h -a title,global,o,c,"MiCASA Daily NDVI fPAR Vegetation Indices $RESLONG v$VERSION" "$fout"
            ncatted -O -h -a LongName,global,o,c,"MiCASA Daily NDVI fPAR Vegetation Indices $RESLONG" "$fout"
            ncatted -O -h -a ShortName,global,o,c,'MICASA_VEGIND_M' "$fout"
            ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
            ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
            ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
            ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#           ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#           ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
#           ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$ff" "$fout"
#           ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$fchk" "$fout"
            ncatted -O -h -a ReadMeURL,global,o,c,"$SERVE/$HEADDOC/MiCASA_README.pdf" "$fout"
            ncatted -O -h -a RangeBeginningDate,global,o,c,"$year-$mon-$day" "$fout"
            ncatted -O -h -a RangeBeginningTime,global,o,c,"00:00:00.000000" "$fout"
            ncatted -O -h -a RangeEndingDate,global,o,c,"$year-$mon-$day" "$fout"
            ncatted -O -h -a RangeEndingTime,global,o,c,"23:59:59.999999" "$fout"
            ncatted -O -h -a NorthernmostLatiude,global,o,c,'90.0' "$fout"
            ncatted -O -h -a WesternmostLongitude,global,o,c,'-180.0' "$fout"
            ncatted -O -h -a SouthernmostLatitude,global,o,c,'-90.0' "$fout"
            ncatted -O -h -a EasternmostLongitude,global,o,c,'180.0' "$fout"
            ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"

            # Update checksum
            (
            cd "$DIROUT/vegind/$year" || exit
            shasum -a 256 "$ff" >> "$fchk"
            cd - > /dev/null || exit
            )
        fi
    fi

#   BURN
#==============================================================================
    ndays=0
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="MiCASA_v${VERSION}_burn_${RESTAG}_daily_$year$mon$day.$FEXT"
        fin="$DIRIN/burn/$year/$ff"
        fout="$DIROUT/burn/$year/$ff"

        if [[ -f "$fin" ]]; then
            ndays=$((ndays + 1))
            if [[ ! -f "$fout" || "$REPRO" == true ]]; then
                nproc=$((nproc + 1))
                mkdir -p "$DIROUT/burn/$year"
                cpcmd "$fin" "$fout"
            fi
        fi

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Daily NDVI fPAR Vegetation Indices $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Daily NDVI fPAR Vegetation Indices $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_VEGIND_D' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#       ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#       ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
#       ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$ff" "$fout"
#       ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$fchk" "$fout"
        ncatted -O -h -a ReadMeURL,global,o,c,"$SERVE/$HEADDOC/MiCASA_README.pdf" "$fout"
        ncatted -O -h -a RangeBeginningDate,global,o,c,"$year-$mon-$day" "$fout"
        ncatted -O -h -a RangeBeginningTime,global,o,c,"00:00:00.000000" "$fout"
        ncatted -O -h -a RangeEndingDate,global,o,c,"$year-$mon-$day" "$fout"
        ncatted -O -h -a RangeEndingTime,global,o,c,"23:59:59.999999" "$fout"
        ncatted -O -h -a NorthernmostLatiude,global,o,c,'90.0' "$fout"
        ncatted -O -h -a WesternmostLongitude,global,o,c,'-180.0' "$fout"
        ncatted -O -h -a SouthernmostLatitude,global,o,c,'-90.0' "$fout"
        ncatted -O -h -a EasternmostLongitude,global,o,c,'180.0' "$fout"
        ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"

        # Update checksum
        (
        cd "$DIROUT/burn/$year" || exit
        shasum -a 256 "$ff" >> "$fchk"
        cd - > /dev/null || exit
        )
    done

    echo "$year/$mon: Processed $nproc daily files out of $ndays"

#   MONTHLY
#==============================================================================
    ff="${COLTAG}_monthly_$year$mon.$FEXT"
    fin="$DIRIN/monthly/$year/$ff"
    fout="$DIROUT/monthly/$year/$ff"
    fchk="${COLTAG}_monthly_$year${mon}_sha256.txt"

    [[ -f "$fout" && "$REPRO" != true ]] && continue		# Skip if file exists and not reprocessing
    [[ $ndays -ne $monlen ]] && continue			# Skip if not all daily outputs are available

    mkdir -p "$DIROUT/monthly/$year"

    # A little extra in case $fin == $fout
    ftmp="${fout%$FEXT}tmp.$FEXT"
    nccopy -s -d 9 "$fin" "$ftmp"
    mv "$ftmp" "$fout"

    ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
    ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
    ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
    ncatted -O -h -a title,global,o,c,"MiCASA Monthly NPP Rh ATMC NEE FIRE FUEL Fluxes $RESTAG v$VERSION" "$fout"
    ncatted -O -h -a LongName,global,o,c,"MiCASA Monthly NPP Rh ATMC NEE FIRE FUEL Fluxes $RESTAG" "$fout"
    ncatted -O -h -a ShortName,global,o,c,'MICASA_FLUX_M' "$fout"
    ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
    ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
    ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
    ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
    ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
    ncatted -O -h -a IdentifierProductDOI,global,o,c,'10.5067/UCFEAAIDIUEQ' "$fout"
#   ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/monthly/$year/$mon/$ff" "$fout"
#   ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/monthly/$year/$mon/$fchk" "$fout"
    ncatted -O -h -a ReadMeURL,global,o,c,"$SERVE/$HEADDOC/MiCASA_README.pdf" "$fout"
    ncatted -O -h -a RangeBeginningDate,global,o,c,"$year-$mon-01" "$fout"
    ncatted -O -h -a RangeBeginningTime,global,o,c,"00:00:00.000000" "$fout"
    ncatted -O -h -a RangeEndingDate,global,o,c,"$year-$mon-$monlen" "$fout"
    ncatted -O -h -a RangeEndingTime,global,o,c,"23:59:59.999999" "$fout"
    ncatted -O -h -a NorthernmostLatiude,global,o,c,'90.0' "$fout"
    ncatted -O -h -a WesternmostLongitude,global,o,c,'-180.0' "$fout"
    ncatted -O -h -a SouthernmostLatitude,global,o,c,'-90.0' "$fout"
    ncatted -O -h -a EasternmostLongitude,global,o,c,'180.0' "$fout"
    ncatted -O -h -a comment,global,o,c,"$COMMENT" "$fout"
    ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"

    # Overwrite checksum
    (
    cd "$DIROUT/monthly/$year" || exit
    shasum -a 256 "$ff" > "$fchk"
    cd - > /dev/null || exit
    )

    echo "$year/$mon: Processed monthly file"
done
