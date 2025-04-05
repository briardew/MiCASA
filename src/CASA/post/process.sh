#!/bin/bash

COMMENT='Positive NPP indicates uptake by vegetation. Positive Rh indicates emission to the atmosphere. NEE = Rh - NPP - ATMC, and NBE = NEE + FIRE + FUEL. ATMC adjusts net exchange to account for missing processes and better match long-term atmospheric budgets.'

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# Get and check arguments
# ---
usage() {
    echo "usage: $(basename "$0") year [options]"
    echo ""
    echo "Post-process MiCASA data"
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

BATCH=false
MON0=01
MONF=12

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
echo "MiCASA post-processing" 
echo "---"
echo "Input  directory: $DIRIN"
echo "Output directory: $DIROUT"
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
#   3HRLY
#==============================================================================
    fchk="${COLTAG}_3hrly_$year${mon}_sha256.txt"
    [[ "$REPRO" == true && -f "$fchk" ]] && rm "$fchk"		# Delete old checksum if repro

    monlen=$(date -d "$year/$mon/1 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="${COLTAG}_3hrly_$year$mon$day.$FEXT"
        fin="$DIRIN/3hrly/$year/$mon/$ff"
        fout="$DIROUT/3hrly/$year/$mon/$ff"

        [[ ! -f "$fin" ]] && continue				# Skip if input file is missing
        ndays=$((ndays + 1))
        [[ -f "$fout" && "$REPRO" != true ]] && continue	# Skip if 3hrly file exists and not repro
        nproc=$((nproc + 1))

        mkdir -p "$DIROUT/3hrly/$year/$mon"

        # A little extra in case $fin == $fout
        ftmp="${fout%$FEXT}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA 3-hourly NPP NEE Fluxes $RESTAG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA 3-hourly NPP NEE Fluxes $RESTAG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_FLUX_3H' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
        ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
        ncatted -O -h -a IdentifierProductDOI,global,o,c,'10.5067/AS9U6AWVTY69' "$fout"
#       ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/3hrly/$year/$mon/$ff" "$fout"
#       ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/3hrly/$year/$mon/$fchk" "$fout"
        ncatted -O -h -a ReadMeURL,global,o,c,"$SERVE/$HEADDOC/MiCASA_README.pdf" "$fout"
        ncatted -O -h -a RangeBeginningDate,global,o,c,"$year-$mon-$day" "$fout"
        ncatted -O -h -a RangeBeginningTime,global,o,c,"00:00:00.000000" "$fout"
        ncatted -O -h -a RangeEndingDate,global,o,c,"$year-$mon-$day" "$fout"
        ncatted -O -h -a RangeEndingTime,global,o,c,"23:59:59.999999" "$fout"
        ncatted -O -h -a NorthernmostLatiude,global,o,c,'90.0' "$fout"
        ncatted -O -h -a WesternmostLongitude,global,o,c,'-180.0' "$fout"
        ncatted -O -h -a SouthernmostLatitude,global,o,c,'-90.0' "$fout"
        ncatted -O -h -a EasternmostLongitude,global,o,c,'180.0' "$fout"
        ncatted -O -h -a comment,global,o,c,"$COMMENT" "$fout"
        ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"

        # Update checksum
        (
        cd "$DIROUT/3hrly/$year/$mon" || exit
        shasum -a 256 "$ff" >> "$fchk"
        cd - > /dev/null || exit
        )
    done

    echo ""
    echo "$year/$mon: Processed $nproc 3hrly files out of $ndays"

#   DAILY
#==============================================================================
    fchk="${COLTAG}_daily_$year${mon}_sha256.txt"
    [[ "$REPRO" == true && -f "$fchk" ]] && rm "$fchk"		# Delete old checksum if repro

    monlen=$(date -d "$year/$mon/1 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="${COLTAG}_daily_$year$mon$day.$FEXT"
        fin="$DIRIN/daily/$year/$mon/$ff"
        fout="$DIROUT/daily/$year/$mon/$ff"

        [[ ! -f "$fin" ]] && continue				# Skip if input file is missing
        ndays=$((ndays + 1))
        [[ -f "$fout" && "$REPRO" != true ]] && continue	# Skip if file exists and not repro
        nproc=$((nproc + 1))

        mkdir -p "$DIROUT/daily/$year/$mon"

        # A little extra in case $fin == $fout
        ftmp="${fout%$FEXT}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Daily NPP Rh ATMC NEE FIRE FUEL Fluxes $RESTAG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Daily NPP Rh ATMC NEE FIRE FUEL Fluxes $RESTAG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_FLUX_D' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
        ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
        ncatted -O -h -a IdentifierProductDOI,global,o,c,'10.5067/ZBXSA1LEN453' "$fout"
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
        ncatted -O -h -a comment,global,o,c,"$COMMENT" "$fout"
        ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"

        # Update checksum
        (
        cd "$DIROUT/daily/$year/$mon" || exit
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
