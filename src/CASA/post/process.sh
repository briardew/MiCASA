#!/bin/bash

# NB: Keeping this named "process.sh", but may mv to "fluxes.sh"

BLURB="MiCASA flux post-processor"

# Process settings & arguments
# ---
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
echo "Collection: $FLUXHEAD"
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

# COMPRESS
# ===
for mon in $(seq -f %02g "$MON0" "$MONF"); do
    # 3-Hourly
    # ---
    # BEWARE: Filenames have underscores that are valid in variable names
    # Being extra cautious about protecting variables with braces in file name
    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
    ndays=0
    nproc=0
    for day in $(seq -f "%02g" 01 "$monlen"); do
        ff="${FLUXHEAD}_3hrly_${year}${mon}${day}.${FEXT}"
        fin="$DIRIN/3hrly/$year/$mon/$ff"

        # Skip if input file is missing
        [[ ! -f "$fin" ]] && continue
        ndays=$((ndays + 1))

        # Skip if input file is already compressed
        nmatch=$(ncdump -h "$fin" | grep -c '    :stage = "intermediate" ;')
        [[ "$nmatch" -eq 0 ]] && continue
        nproc=$((nproc + 1))

        # nccopy needs unique input and output files
        ftmp="${fin%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        ncatted -O -h -a stage,global,d,, "$ftmp"
        mv "$ftmp" "$fin"
    done

    echo ""
    echo "$year/$mon: Processed $nproc out of $ndays 3hrly flux file(s)"

    # Daily
    # ---
    ndays=0
    nproc=0
    for day in $(seq -f "%02g" 01 "$monlen"); do
        ff="${FLUXHEAD}_daily_${year}${mon}${day}.${FEXT}"
        fin="$DIRIN/daily/$year/$mon/$ff"

        # Skip if input file is missing
        [[ ! -f "$fin" ]] && continue
        ndays=$((ndays + 1))

        # Skip if file exists and not overwriting
        nmatch=$(ncdump -h "$fin" | grep -c '    :stage = "intermediate" ;')
        [[ "$nmatch" -eq 0 ]] && continue
        nproc=$((nproc + 1))

        # nccopy needs unique input and output files
        ftmp="${fin%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        ncatted -O -h -a stage,global,d,, "$ftmp"
        mv "$ftmp" "$fin"
    done

    echo "$year/$mon: Processed $nproc out of $ndays daily flux file(s)"

    # Monthly
    # ---
    ff="${FLUXHEAD}_monthly_${year}${mon}.${FEXT}"
    fin="$DIRIN/monthly/$year/$ff"

    # Skip if file exists and not overwriting
    nmatch=$(ncdump -h "$fin" | grep -c '    :stage = "intermediate" ;')
    [[ "$nmatch" -eq 0 ]] && continue

    # nccopy needs unique input and output files
    ftmp="${fin%"$FEXT"}tmp.$FEXT"
    nccopy -s -d 9 "$fin" "$ftmp"
    ncatted -O -h -a stage,global,d,, "$ftmp"
    mv "$ftmp" "$fin"

    echo "$year/$mon: Processed monthly flux file"
done

# CREATE CHECKSUMS
# ===

# PUBLISH
# ===
        mkdir -p "$ROOTPUB/$HEADOUT/3hrly/$year/$mon"
        rsync -av "$fout" "$(echo $fout | sed -e "s?$ROOTOUT?$ROOTPUB?")"

        mkdir -p "$ROOTPUB/$HEADOUT/daily/$year/$mon"
        rsync -av "$fout" "$(echo $fout | sed -e "s?$ROOTOUT?$ROOTPUB?")"

mkdir -p "$ROOTPUB/$HEADOUT/monthly/$year"
rsync -av "$fout" "$(echo $fout | sed -e "s?$ROOTOUT?$ROOTPUB?")"
