#!/usr/bin/env bash

# Post-process output collections

# Be strict about errors
set -euo pipefail

BLURB="MiCASA output post-processor"

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
echo "Output collection(s): ${COLSOUT[*]}"
echo "Public collection(s): ${COLSPUB[*]}"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

warnings

echo ""

# COMPRESSION & CHECKSUM
# ===
# BEWARE: Filenames have underscores that are valid in variable names
# Being extra cautious about protecting variables with braces in file name
for col in "${COLSOUT[@]}"; do
    HEADCOL="${PROD}_v${VER}_${col}_$RES"
    # Only fluxes have 3hrly collection
    [[ "$col" == "flux" ]] && FREAKS=("3hrly" "daily") || FREAKS=("daily")

    for mon in $(seq -f %02g "$MON0" "$MONF"); do
        # 3-Hourly & Daily
        # ---
        monlen=$(date -d "$year-$mon-01 + 1 month - 1 day" "+%d")
        for freq in "${FREAKS[@]}"; do
            # Compression
            # ---
            ndays=0
            nproc=0
            for day in $(seq -f "%02g" 01 "$monlen"); do
                ff="${HEADCOL}_${freq}_${year}${mon}${day}.$FEXT"
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

            echo "$year-$mon: Compressed $nproc out of $ndays $freq $col file(s)"
            echo ""

            # Checksum
            # ---
            fin="${HEADCOL}_${freq}_${year}${mon}??.$FEXT"
            fchk="${HEADCOL}_${freq}_${year}${mon}_sha256.txt"
            (
                cd "$DINFLX/$freq/$year/$mon" || exit

                findargs=("-mindepth" 1 "-maxdepth" 1 "-type" f)
                # Only overwrite checksum if file(s) are newer than it
                [[ -f "$fchk" ]] && findargs+=("-newer" "$fchk")

                fnew=$(find . "${findargs[@]}" -name "$fin")

                if [[ ${#fnew} -gt 0 ]]; then
                    echo "$year-$mon: Creating $freq $col checksum $fchk"
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
        ff="${HEADCOL}_monthly_${year}${mon}.$FEXT"
        fin="$DINFLX/monthly/$year/$ff"

        # Skip if input file is missing
        [[ ! -f "$fin" ]] && continue

        # Skip if file exists and not overwriting
        nmatch=$(ncdump -h "$fin" | grep -c ':stage = "intermediate" ;' || true)
        [[ "$nmatch" -eq 0 ]] && continue

        # nccopy needs unique input and output files
        ftmp="${fin%"$FEXT"}tmp.$FEXT"
        nccopy -s -d 9 "$fin" "$ftmp"
        ncatted -O -h -a stage,global,d,, "$ftmp"
        mv "$ftmp" "$fin"

        echo "$year-$mon: Compressed monthly $col file"
        echo ""
    done

    # Monthly checksum
    # ---
    # A reasonable? compromise to avoid races
    if [[ "$MONF" -eq 12 ]]; then
        fin="${HEADCOL}_monthly_${year}??.$FEXT"
        fchk="${HEADCOL}_monthly_${year}_sha256.txt"
        (
            cd "$DINFLX/monthly/$year" || exit

            findargs=("-mindepth" 1 "-maxdepth" 1 "-type" f)
            # Only overwrite checksum if file(s) are newer than it
            [[ -f "$fchk" ]] && findargs+=("-newer" "$fchk")

            fnew=$(find . "${findargs[@]}" -name "$fin")

            if [[ ${#fnew} -gt 0 ]]; then
                echo "$year: Creating $col checksum $fchk"
                echo ""
                for ff in $fin; do
                    shasum -a 256 "$(basename "$ff")"
                done > "$fchk"
            fi

            cd - > /dev/null || exit
        )
    fi
done

# PUBLISH
# ===
# rsync will make sub-directories, but not root
for col in "${COLSPUB[@]}"; do
    HEADCOL="${PROD}_v${VER}_${col}_$RES"
    mkdir -p "$DOUTFLX"
    (
        cd "$DINFLX" || exit

        # Make sure null file globs return empty lists
        shopt -s nullglob

        flist=()
        for mon in $(seq -f %02g "$MON0" "$MONF"); do
            flist+=("3hrly/$year/$mon/${HEADCOL}_3hrly_${year}${mon}"*)
            flist+=("daily/$year/$mon/${HEADCOL}_daily_${year}${mon}"*)
            fmon="monthly/$year/${HEADCOL}_monthly_${year}${mon}.$FEXT"
            [[ -f "$fmon" ]] && flist+=("$fmon")
        done
        # A reasonable? compromise to avoid races
        if [[ "$MONF" -eq 12 ]]; then
            fchk="monthly/$year/${HEADCOL}_monthly_${year}_sha256.txt"
            [[ -f "$fchk" ]] && flist+=("$fchk")
        fi

        # Return to normal globbing
        shopt -u nullglob

        "$CPCMD" "${CPARGS[@]}" "${flist[@]}" "$DOUTFLX/" || exit $?

        cd - > /dev/null || exit
    )
done
