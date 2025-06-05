#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# Get and check arguments
# ---
usage() {
    echo "usage: $(basename "$0") year [options]"
    echo ""
    echo "Post-process MiCASA drivers"
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
echo "MiCASA driver post-processing" 
echo "---"
echo "Input  directory: $VEGIN"
echo "Output directory: $DIRVEG"
echo "Collection(s): cover, vegind, burn"
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

# LAND COVER
#==============================================================================
# BEWARE: Filenames have underscores that are valid in variable names
# Being extra cautious about protecting variables with braces in file name
VEGTAG="MiCASA_v${VERSION}_cover_${RESTAG}"
ff="${VEGTAG}_yearly_${year}.${FEXT}"
fin="$VEGIN/cover/$ff"
fout="$DIRVEG/cover/$ff"
fchk="${VEGTAG}_yearly_${year}_sha256.txt"

if [[ ! -f "$fout" || "$REPRO" == true ]]; then
    mkdir -p "$DIRVEG/cover"

    # A little extra in case $fin == $fout
    ftmp="${fout%"$FEXT"}tmp.$FEXT"
    nccopy -s -d 9 "$fin" "$ftmp"
    mv "$ftmp" "$fout"

    ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
    ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
    ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
    ncatted -O -h -a title,global,o,c,"MiCASA Yearly Land Cover $RESLONG v$VERSION" "$fout"
    ncatted -O -h -a LongName,global,o,c,"MiCASA Yearly Land Cover $RESLONG" "$fout"
    ncatted -O -h -a ShortName,global,o,c,'MICASA_COVER_Y' "$fout"
    ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
    ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
    ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
    ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#   ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#   ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
    ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADVEG/cover/$ff" "$fout"
    ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADVEG/cover/$fchk" "$fout"
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
    cd "$DIRVEG/cover" || exit
    shasum -a 256 "$ff" > "$fchk"
    cd - > /dev/null || exit
    )

    echo "$year: Processed yearly cover file"
fi

for mon in $(seq -f "%02g" $MON0 $MONF); do
#   VEGETATION INDICES: DAILY
#==============================================================================
    VEGTAG="MiCASA_v${VERSION}_vegind_${RESTAG}"

    fchk="${VEGTAG}_daily_${year}${mon}_sha256.txt"
    # Delete old checksum if repro
    [[ "$REPRO" == true && -f "$fchk" ]] && rm "$fchk"

    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="${VEGTAG}_daily_${year}${mon}${day}.${FEXT}"
        fin="$VEGIN/vegind/$year/$ff"
        fout="$DIRVEG/vegind/$year/$ff"

        # Skip if input file is missing
        [[ ! -f "$fin" ]] && continue
        ndays=$((ndays + 1))

        # Skip if file exists and not repro
        [[ -f "$fout" && "$REPRO" != true ]] && continue
        nproc=$((nproc + 1))

        mkdir -p "$DIRVEG/vegind/$year"

        # A little extra in case $fin == $fout
        ftmp="${fout%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Daily Vegetation Indices $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Daily Vegetation Indices $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_VEGIND_D' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#       ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#       ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
        ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADVEG/vegind/$year/$ff" "$fout"
        ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADVEG/vegind/$year/$fchk" "$fout"
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
        cd "$DIRVEG/vegind/$year" || exit
        shasum -a 256 "$ff" >> "$fchk"
        cd - > /dev/null || exit
        )
    done

    echo "$year/$mon: Processed $nproc daily vegind file(s) out of $ndays"

#   VEGETATION INDICES: MONTHLY
#==============================================================================
    ff="${VEGTAG}_monthly_${year}${mon}.${FEXT}"
    fin="$VEGIN/vegind/$year/$ff"
    fout="$DIRVEG/vegind/$year/$ff"
    fchk="${VEGTAG}_monthly_${year}${mon}_sha256.txt"

    if [[ (! -f "$fout" || "$REPRO" == true) && $ndays -eq $monlen ]]; then
        # A little extra because we don't actually make veg monthlies
        if [[ ! -f "$fin" ]]; then
            ncea "$VEGIN/vegind/$year/${VEGTAG}_daily_${year}${mon}"??".${FEXT}" "$fin"
        fi

        mkdir -p "$DIRVEG/vegind/$year"

        # A little extra in case $fin == $fout
        ftmp="${fout%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Monthly Vegetation Indices $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Monthly Vegetation Indices $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_VEGIND_M' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#       ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#       ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
        ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADVEG/vegind/$year/$ff" "$fout"
        ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADVEG/vegind/$year/$fchk" "$fout"
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
        cd "$DIRVEG/vegind/$year" || exit
        shasum -a 256 "$ff" > "$fchk"
        cd - > /dev/null || exit
        )

        echo "$year/$mon: Processed monthly vegind file"
    fi

#   BIOMASS BURNING: DAILY
#==============================================================================
    VEGTAG="MiCASA_v${VERSION}_burn_${RESTAG}"

    fchk="${VEGTAG}_daily_${year}${mon}_sha256.txt"
    # Delete old checksum if repro
    [[ "$REPRO" == true && -f "$fchk" ]] && rm "$fchk"

    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="${VEGTAG}_daily_${year}${mon}${day}.${FEXT}"
        fin="$VEGIN/burn/$year/$ff"
        fout="$DIRVEG/burn/$year/$ff"

        # Skip if input file is missing
        [[ ! -f "$fin" ]] && continue
        ndays=$((ndays + 1))

        # Skip if file exists and not repro
        [[ -f "$fout" && "$REPRO" != true ]] && continue
        nproc=$((nproc + 1))

        mkdir -p "$DIRVEG/burn/$year"

        # A little extra in case $fin == $fout
        ftmp="${fout%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Daily Biomass Burning $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Daily Biomass Burning $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_BURN_D' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#       ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#       ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
        ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADVEG/burn/$year/$ff" "$fout"
        ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADVEG/burn/$year/$fchk" "$fout"
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
        cd "$DIRVEG/burn/$year" || exit
        shasum -a 256 "$ff" >> "$fchk"
        cd - > /dev/null || exit
        )
    done

    echo "$year/$mon: Processed $nproc daily burn file(s) out of $ndays"

#   BIOMASS BURNING: MONTHLY
#==============================================================================
    ff="${VEGTAG}_monthly_${year}${mon}.${FEXT}"
    fin="$VEGIN/burn/$year/$ff"
    fout="$DIRVEG/burn/$year/$ff"
    fchk="${VEGTAG}_monthly_${year}${mon}_sha256.txt"

    if [[ (! -f "$fout" || "$REPRO" == true) && $ndays -eq $monlen ]]; then
        mkdir -p "$DIRVEG/burn/$year"

        # A little extra in case $fin == $fout
        ftmp="${fout%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Monthly Biomass Burning $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Monthly Biomass Burning $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_BURN_M' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
#       ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
#       ncatted -O -h -a IdentifierProductDOI,global,o,c,'' "$fout"
        ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADVEG/burn/$year/$ff" "$fout"
        ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADVEG/burn/$year/$fchk" "$fout"
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
        cd "$DIRVEG/burn/$year" || exit
        shasum -a 256 "$ff" > "$fchk"
        cd - > /dev/null || exit
        )

        echo "$year/$mon: Processed monthly burn file"
    fi
done
