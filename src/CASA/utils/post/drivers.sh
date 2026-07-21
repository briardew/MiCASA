#!/usr/bin/env bash

# Be strict about errors
set -euo pipefail

BLURB="MiCASA driver post-processor"

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
echo "Input location: $DINDRV"
echo "Output location: $DOUTDRV"
echo "Collection(s): cover, vegind, burn"
echo "Year: $year"
echo "Month(s): $MON0..$MONF"

warnings

echo ""

# CHECKSUMS
# ===
# Land cover
# ---
# A reasonable? compromise to avoid races
if [[ "$MON0" -eq 1 ]]; then
    # This can race if different years are run in parallel. Maybe just don't?
    fin="${PROD}_v${VER}_cover_${RES}_yearly_????.$FEXT"
    fchk="${PROD}_v${VER}_cover_${RES}_yearly_sha256.txt"
    (
        cd "$DINDRV/cover" || exit

        findargs=("-mindepth" 1 "-maxdepth" 1 "-type" f)
        # Only overwrite checksum if file(s) are newer than it
        [[ -f "$fchk" ]] && findargs+=("-newer" "$fchk")

        fnew=$(find . "${findargs[@]}" -name "$fin")

        if [[ ${#fnew} -gt 0 ]]; then
            echo "Creating yearly cover checksum $fchk"
            echo ""
            for ff in $fin; do
                shasum -a 256 "$(basename "$ff")"
            done > "$fchk"
        fi

        cd - > /dev/null || exit
    )
fi

# Vegetation index & Burned area
# ---
# A reasonable? compromise to avoid races
if [[ "$MONF" -eq 12 ]]; then
    for tag in vegind burn; do
        (
            cd "$DINDRV/$tag/$year" || exit

            for freq in daily monthly; do
                fin="${PROD}_v${VER}_${tag}_${RES}_${freq}_${year}*.$FEXT"
                fchk="${PROD}_v${VER}_${tag}_${RES}_${freq}_${year}_sha256.txt"

                findargs=("-mindepth" 1 "-maxdepth" 1 "-type" f)
                # Only overwrite checksum if file(s) are newer than it
                [[ -f "$fchk" ]] && findargs+=("-newer" "$fchk")

                fnew=$(find . "${findargs[@]}" -name "$fin")

                if [[ ${#fnew} -gt 0 ]]; then
                    echo "$year: Creating $freq $tag checksum $fchk"
                    echo ""
                    for ff in $fin; do
                        shasum -a 256 "$(basename "$ff")"
                    done > "$fchk"
                fi
            done

            cd - > /dev/null || exit
        )
    done
fi

# PUBLISH
# ===
# rsync will make sub-directories, but not root
mkdir -p "$DOUTDRV"
(
    cd "$DINDRV" || exit

    # Make sure null file globs return empty lists
    shopt -s nullglob

    flist=()
    # A reasonable? compromise to avoid races
    if [[ "$MON0" -eq 1 ]]; then
        flist+=("cover/${PROD}_v${VER}_cover_${RES}_yearly_$year.$FEXT")
        flist+=("cover/${PROD}_v${VER}_cover_${RES}_yearly_sha256.txt")
    fi
    for mon in $(seq -f %02g "$MON0" "$MONF"); do
        flist+=("vegind/$year/${PROD}_v${VER}_vegind_${RES}_"*"_$year$mon"*)
        flist+=("burn/$year/${PROD}_v${VER}_burn_${RES}_"*"_$year$mon"*)
    done
    # A reasonable? compromise to avoid races
    if [[ "$MONF" -eq 12 ]]; then
        flist+=("vegind/$year/${PROD}_v${VER}_vegind_${RES}_"*"_sha256.txt")
        flist+=("burn/$year/${PROD}_v${VER}_burn_${RES}_"*"_sha256.txt")
    fi

    # Return to normal globbing
    shopt -u nullglob

    # Trailing slashes are necessary for rsync as is exit to capture SIGINT
    "$CPCMD" "${CPARGS[@]}" "${flist[@]}" "$DOUTDRV/" || exit $?

    cd - > /dev/null || exit
)
