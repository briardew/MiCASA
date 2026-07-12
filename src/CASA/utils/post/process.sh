#!/usr/bin/env bash

# NB: Keeping this named "process.sh", but may mv to "fluxes.sh"

BLURB="MiCASA flux post-processor"

# Process settings & arguments
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR/../../setup.sh"

argparse "$(basename "$0")" "$BLURB" "$@"

# Outputs and warnings
# ---
echo "---"
echo "$BLURB" 
echo "---"
echo "Input location: $DINFLX"
echo "Output location: $DOUTFLX"
echo "Collection: $HEADFLX"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

warnings

echo ""

# COMPRESSION & CHECKSUM
# ===
# BEWARE: Filenames have underscores that are valid in variable names
# Being extra cautious about protecting variables with braces in file name
for mon in $(seq -f %02g "$MON0" "$MONF"); do
    # 3-Hourly & Daily
    # ---
    monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
    for freq in 3hrly daily; do
        # Compression
        # ---
        ndays=0
        nproc=0
        for day in $(seq -f "%02g" 01 "$monlen"); do
            ff="${HEADFLX}_${freq}_${year}${mon}${day}.$FEXT"
            fin="$DINFLX/$freq/$year/$mon/$ff"

            # Skip if input file is missing
            [[ ! -f "$fin" ]] && continue
            ndays=$((ndays + 1))

            # Skip if input file is already compressed
            nmatch=$(ncdump -h "$fin" | grep -c ':stage = "intermediate" ;' || true)
            [[ "$nmatch" -eq 0 ]] && continue
            nproc=$((nproc + 1))

            echo "$year-$mon-$day: Compressing $ff"
            # nccopy needs unique input and output files
            ftmp="${fin%"$FEXT"}tmp.$FEXT"
            nccopy -s -d 9 "$fin" "$ftmp"
            ncatted -O -h -a stage,global,d,, "$ftmp"
            mv "$ftmp" "$fin"
        done

        echo "$year-$mon: Compressed $nproc out of $ndays $freq flux file(s)"
        echo ""

        # Checksum
        # ---
        fin="${HEADFLX}_${freq}_${year}${mon}??.$FEXT"
        fchk="${HEADFLX}_${freq}_${year}${mon}_sha256.txt"
        (
            cd "$DINFLX/$freq/$year/$mon" || exit

            findargs=("-mindepth" 1 "-maxdepth" 1 "-type" f)
            # Only overwrite checksum if file(s) are newer than it
            [[ -f "$fchk" ]] && findargs+=("-newer" "$fchk")

            fnew=$(find . "${findargs[@]}" -name "$fin")

            if [[ ${#fnew} -gt 0 ]]; then
                echo "$year-$mon: Creating $freq flux checksum $fchk"
                echo ""
                for ff in $fin; do
                    shasum -a 256 "$(basename "$ff")"
                done > "$fchk"
            fi

            cd - > /dev/null || exit
        )
    done

    # Monthly compression
    # ---
    ff="${HEADFLX}_monthly_${year}${mon}.$FEXT"
    fin="$DINFLX/monthly/$year/$ff"

    # Skip if file exists and not overwriting
    nmatch=$(ncdump -h "$fin" | grep -c ':stage = "intermediate" ;' || true)
    [[ "$nmatch" -eq 0 ]] && continue

    # nccopy needs unique input and output files
    ftmp="${fin%"$FEXT"}tmp.$FEXT"
    nccopy -s -d 9 "$fin" "$ftmp"
    ncatted -O -h -a stage,global,d,, "$ftmp"
    mv "$ftmp" "$fin"

    echo "$year-$mon: Compressed monthly flux file"
    echo ""
done

# Monthly checksum
# ---
# A reasonable? compromise to avoid races
if [[ "$MONF" -eq 12 ]]; then
    fin="${HEADFLX}_monthly_${year}??.$FEXT"
    fchk="${HEADFLX}_monthly_${year}_sha256.txt"
    (
        cd "$DINFLX/monthly/$year" || exit

        findargs=("-mindepth" 1 "-maxdepth" 1 "-type" f)
        # Only overwrite checksum if file(s) are newer than it
        [[ -f "$fchk" ]] && findargs+=("-newer" "$fchk")

        fnew=$(find . "${findargs[@]}" -name "$fin")

        if [[ ${#fnew} -gt 0 ]]; then
            echo "$year: Creating flux checksum $fchk"
            echo ""
            for ff in $fin; do
                shasum -a 256 "$(basename "$ff")"
            done > "$fchk"
        fi

        cd - > /dev/null || exit
    )
fi

# PUBLISH
# ===
# rsync will make sub-directories, but not root
mkdir -p "$DOUTFLX"
(
    cd "$DINFLX" || exit

    # Make sure null file globs return empty lists
    shopt -s nullglob

    flist=()
    for mon in $(seq -f %02g "$MON0" "$MONF"); do
        flist+=("3hrly/$year/$mon/${HEADFLX}_3hrly_${year}${mon}"*)
        flist+=("daily/$year/$mon/${HEADFLX}_daily_${year}${mon}"*)
        flist+=("monthly/$year/${HEADFLX}_monthly_${year}${mon}.$FEXT")
    done
    # A reasonable? compromise to avoid races
    if [[ "$MONF" -eq 12 ]]; then
        flist+=("monthly/$year/${HEADFLX}_monthly_${year}_sha256.txt")
    fi

    # Return to normal globbing
    shopt -u nullglob

    "$CPCMD" "${CPARGS[@]}" "${flist[@]}" "$DOUTFLX/" || exit $?

    cd - > /dev/null || exit
)
