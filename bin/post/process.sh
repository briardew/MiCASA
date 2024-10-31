#!/bin/bash

echo "---"
echo "MiCASA post-processing" 
echo "---"

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

COMMENT='Positive NPP indicates uptake by vegetation. Positive Rh indicates emission to the atmosphere. NEE = Rh - NPP - ATMC, and NBE = NEE + FIRE + FUEL. ATMC adjusts net exchange to account for missing processes and better match long-term atmospheric budgets.'

# Simple outputs, warnings, and errors
# Would be nice to have a help file (***FIXME***)
[[ "$REPRO" == true ]] && echo "WARNING: Reprocessing, will overwrite files ..." 1>&2

echo "Input  directory: $DIRIN"
echo "Output directory: $DIROUT"
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
#   3HRLY
#==============================================================================
    fchk="${COLTAG}_3hrly_$year${mon}_sha256.txt"
    [[ "$REPRO" == true && -f "$fchk" ]] && rm "$fchk"		# Delete old checksum if repro

    monlen=$(date -d "$year/$mon/1 + 1 month - 1 day" "+%d")
    flist=()
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="${COLTAG}_3hrly_$year$mon$day.$FEXT"
        fin="$DIRIN/3hrly/$year/$mon/$ff"
        fout="$DIROUT/3hrly/$year/$mon/$ff"

        flist+=("$fout")
        [[ -f "$fout" && "$REPRO" != true ]] && continue	# Skip if 3hrly file exists and not repro
        [[ ! -f "$fin" ]] && exit				# Exit if input file is missing
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
    echo "$year/$mon: Processed $nproc 3-hourly files"

#   DAILY
#==============================================================================
    fchk="${COLTAG}_daily_$year${mon}_sha256.txt"
    [[ "$REPRO" == true && -f "$fchk" ]] && rm "$fchk"		# Delete old checksum if repro

    monlen=$(date -d "$year/$mon/1 + 1 month - 1 day" "+%d")
    flist=()
    nproc=0
    for day in $(seq -w 01 "$monlen"); do
        ff="${COLTAG}_daily_$year$mon$day.$FEXT"
        fin="$DIRIN/daily/$year/$mon/$ff"
        fout="$DIROUT/daily/$year/$mon/$ff"

        flist+=("$fout")
        [[ -f "$fout" && "$REPRO" != true ]] && continue	# Skip if file exists and not repro
        [[ ! -f "$fin" ]] && exit				# Exit if input file is missing
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

    echo "$year/$mon: Processed $nproc daily files"

#   MONTHLY
#==============================================================================
    ff="${COLTAG}_monthly_$year$mon.$FEXT"
    fin="$DIRIN/monthly/$year/$ff"
    fout="$DIROUT/monthly/$year/$ff"
    fchk="${COLTAG}_monthly_$year${mon}_sha256.txt"

    [[ -f "$fout" && "$REPRO" != true ]] && continue		# Skip if file exists and not reprocessing
    [[ ${#flist[@]} -ne $monlen ]] && exit			# Exit if not all daily outputs are available

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