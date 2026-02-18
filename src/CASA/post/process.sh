#!/bin/bash

# NB: Keeping this named "process.sh", but may mv to "fluxes.sh"
# But honestly, just transition this to a single Python executable already

COMMENT='Positive NPP indicates uptake by vegetation. Positive Rh indicates emission to the atmosphere. NEE = Rh - NPP - ATMC, and NBE = NEE + FIRE + FUEL. ATMC adjusts net exchange to account for missing processes and better match long-term atmospheric budgets.'
BLURB="MiCASA flux post-processor"

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
echo "Input  directory: $DIRIN"
echo "Output directory: $DIROUT"
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
#   3HRLY
#==============================================================================
    # BEWARE: Filenames have underscores that are valid in variable names
    # Being extra cautious about protecting variables with braces in file name
    fchk="$DIROUT/3hrly/$year/$mon/${FLXTAG}_3hrly_${year}${mon}_sha256.txt"
    [[ "$FORCE" == true && -f "$fchk" ]] && rm "$fchk"		# Delete old checksum if overwriting

    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -f "%02g" 01 "$monlen"); do
        ff="${FLXTAG}_3hrly_${year}${mon}${day}.${FEXT}"
        fin="$DIRIN/3hrly/$year/$mon/$ff"
        fout="$DIROUT/3hrly/$year/$mon/$ff"

        [[ ! -f "$fin" ]] && continue				# Skip if input file is missing
        ndays=$((ndays + 1))
        [[ -f "$fout" && "$FORCE" != true ]] && continue	# Skip if 3hrly file exists and not overwriting
        nproc=$((nproc + 1))

        mkdir -p "$DIROUT/3hrly/$year/$mon"

        # A little extra in case $fin == $fout
        ftmp="${fout%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA 3-hourly NPP NEE Fluxes $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA 3-hourly NPP NEE Fluxes $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_FLUX_3H' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
        ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
        ncatted -O -h -a IdentifierProductDOI,global,o,c,'10.5067/AS9U6AWVTY69' "$fout"
#       ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/3hrly/$year/$mon/$ff" "$fout"
#       ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/3hrly/$year/$mon/$(basename "$fchk")" "$fout"
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

        # Publish
        mkdir -p "$ROOTPUB/$HEADOUT/3hrly/$year/$mon"
        cp "$fout" "$(echo $fout | sed -e "s?$ROOTOUT?$ROOTPUB?")"
        cp "$fchk" "$(echo $fchk | sed -e "s?$ROOTOUT?$ROOTPUB?")"
    done

    echo ""
    echo "$year/$mon: Processed $nproc out of $ndays 3hrly flux file(s)"

#   DAILY
#==============================================================================
    fchk="$DIROUT/daily/$year/$mon/${FLXTAG}_daily_${year}${mon}_sha256.txt"
    [[ "$FORCE" == true && -f "$fchk" ]] && rm "$fchk"		# Delete old checksum if overwriting

    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -f "%02g" 01 "$monlen"); do
        ff="${FLXTAG}_daily_${year}${mon}${day}.${FEXT}"
        fin="$DIRIN/daily/$year/$mon/$ff"
        fout="$DIROUT/daily/$year/$mon/$ff"

        [[ ! -f "$fin" ]] && continue				# Skip if input file is missing
        ndays=$((ndays + 1))
        [[ -f "$fout" && "$FORCE" != true ]] && continue	# Skip if file exists and not overwriting
        nproc=$((nproc + 1))

        mkdir -p "$DIROUT/daily/$year/$mon"

        # A little extra in case $fin == $fout
        ftmp="${fout%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        mv "$ftmp" "$fout"

        ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
        ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
        ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA Daily NPP Rh ATMC NEE FIRE FUEL Fluxes $RESLONG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA Daily NPP Rh ATMC NEE FIRE FUEL Fluxes $RESLONG" "$fout"
        ncatted -O -h -a ShortName,global,o,c,'MICASA_FLUX_D' "$fout"
        ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
        ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
        ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
        ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
        ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
        ncatted -O -h -a IdentifierProductDOI,global,o,c,'10.5067/ZBXSA1LEN453' "$fout"
#       ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$ff" "$fout"
#       ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/daily/$year/$mon/$(basename "$fchk")" "$fout"
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

        # Publish
        mkdir -p "$ROOTPUB/$HEADOUT/daily/$year/$mon"
        cp "$fout" "$(echo $fout | sed -e "s?$ROOTOUT?$ROOTPUB?")"
        cp "$fchk" "$(echo $fchk | sed -e "s?$ROOTOUT?$ROOTPUB?")"
    done

    echo "$year/$mon: Processed $nproc out of $ndays daily flux file(s)"

#   MONTHLY
#==============================================================================
    ff="${FLXTAG}_monthly_${year}${mon}.${FEXT}"
    fin="$DIRIN/monthly/$year/$ff"
    fout="$DIROUT/monthly/$year/$ff"
    fchk="$DIROUT/monthly/$year/${FLXTAG}_monthly_${year}${mon}_sha256.txt"

    [[ -f "$fout" && "$FORCE" != true ]] && continue		# Skip if file exists and not overwriting
    [[ $ndays -ne $monlen ]] && continue			# Skip if not all daily outputs are available

    mkdir -p "$DIROUT/monthly/$year"

    # A little extra in case $fin == $fout
    ftmp="${fout%"$FEXT"}tmp.$FEXT"
    nccopy -s -d 9 "$fin" "$ftmp"
    mv "$ftmp" "$fout"

    ncatted -O -h -a Conventions,global,o,c,'CF-1.9' "$fout"
    ncatted -O -h -a contact,global,o,c,'Brad Weir <brad.weir@nasa.gov>' "$fout"
    ncatted -O -h -a institution,global,o,c,'NASA Goddard Space Flight Center' "$fout"
    ncatted -O -h -a title,global,o,c,"MiCASA Monthly NPP Rh ATMC NEE FIRE FUEL Fluxes $RESLONG v$VERSION" "$fout"
    ncatted -O -h -a LongName,global,o,c,"MiCASA Monthly NPP Rh ATMC NEE FIRE FUEL Fluxes $RESLONG" "$fout"
    ncatted -O -h -a ShortName,global,o,c,'MICASA_FLUX_M' "$fout"
    ncatted -O -h -a VersionID,global,o,c,"$VERSION" "$fout"
    ncatted -O -h -a GranuleID,global,o,c,"$(basename "$fout")" "$fout"
    ncatted -O -h -a Format,global,o,c,'netCDF' "$fout"
    ncatted -O -h -a ProcessingLevel,global,o,c,'4' "$fout"
    ncatted -O -h -a IdentifierProductDOIAuthority,global,o,c,'https://doi.org/' "$fout"
    ncatted -O -h -a IdentifierProductDOI,global,o,c,'10.5067/UCFEAAIDIUEQ' "$fout"
#   ncatted -O -h -a ProductURL,global,o,c,"$SERVE/$HEADOUT/monthly/$year/$mon/$ff" "$fout"
#   ncatted -O -h -a CheckSumURL,global,o,c,"$SERVE/$HEADOUT/monthly/$year/$mon/$(basename "$fchk")" "$fout"
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

    # Publish
    mkdir -p "$ROOTPUB/$HEADOUT/monthly/$year"
    cp "$fout" "$(echo $fout | sed -e "s?$ROOTOUT?$ROOTPUB?")"
    cp "$fchk" "$(echo $fchk | sed -e "s?$ROOTOUT?$ROOTPUB?")"

    echo "$year/$mon: Processed monthly flux file"
done
