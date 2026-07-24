#!/usr/bin/env bash

# This is mainly used for running MiCASA in NRT or updating a retrospective run.
# Long-term the hope is to make it a one-stop shop, but we'll probably convert
# to Python first. To do a retrospective run, see the instructions in the README.

# Be strict about errors
set -euo pipefail

BLURB="Run MiCASA"

# Process settings & arguments
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
CASADIR=$(dirname "$(readlink -f "$0")")
. "$CASADIR/setup.sh"

# Redefine default argument parsing
# ---
usage() {
    echo "usage: $1 [-h] [-p PROD] [-v VER] [-r RES] [--beg YYYY-MM-DD]" \
        "[--end YYYY-MM-DD] [-o DIR] [-f] [-b]"
}

# Defaults (NRT)
daybeg=$(date -d "-$LATENCY days" +%F)					# $LATENCY defined in setup.sh
dayend=$(date -d "-$LATENCY days" +%F)					# $LATENCY defined in setup.sh

helpout() {
    echo "$1"
    echo ""
    echo "options:"
    echo "  -h, --help            show this help message and exit"
    echo "  -p PROD, --prod PROD  product name (default: $PRODDEF)"
    echo "  -v VER, --ver VER     version (default: $VERDEF)"
    echo "  -r RES, --res RES     resolution (default: $RESDEF)"
    echo "  --beg YYYY-MM-DD      begin date (default: $daybeg)"
    echo "  --end YYYY-MM-DD      end date (default: $dayend)"
    echo "  -o DIR, --output DIR  output root directory (default: $DATADEF)"
    echo "  -f, --force           overwrite files (default: False)"
    echo "  -b, --batch           operate in batch mode (default: False)"
}

argparse() {
    # Defaults
    PROD=$PRODDEF
    VER=$VERDEF
    RES=$RESDEF
    DIRDATA=$DATADEF
    FORCE=false
    BATCH=false

    # First two args are for help
    MYNAME="$1"
    BLURB="$2"
    shift 2

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prod)
                PROD="$2"
                shift 2
                ;;
            -v|--ver)
                VER="$2"
                shift 2
                ;;
            -r|--res)
                RES="$2"
                shift 2
                ;;
            --beg)
                if ! daybeg=$(date -d "$2" +%F); then
                    usage "$MYNAME" >&2
                    exit 1
                fi
                shift 2
                ;;
            --end)
                if ! dayend=$(date -d "$2" +%F); then
                    usage "$MYNAME" >&2
                    exit 1
                fi
                shift 2
                ;;
            -o|--output)
                DIRDATA="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -b|--batch)
                BATCH=true
                shift
                ;;
            -h|--help)
                usage "$MYNAME"
                echo ""
                helpout "$BLURB"
                exit
                ;;
            -*|*)
                usage "$MYNAME" >&2
                echo "$MYNAME: error: unknown option $1" >&2
                exit 1
                ;;
        esac
    done
}

# Process arguments
# ---
argparse "$(basename "$0")" "$BLURB" "$@"

# Outputs and warnings
# ---
echo "---"
echo "$BLURB"
echo "---"
echo "Output location: $DIRDATA/v$VER"
echo "Date(s): $daybeg..$dayend"

warnings

# Create drivers
# ---
MVARGS=("--prod" "$PROD" "--ver" "$VER" "--output" "$DIRDATA/v$VER/drivers")
[[ "$FORCE" == true ]] && MVARGS+=("--force")
# A day before start so fill and forecast clean-up work
daybe4=$(date -d "$daybeg-1 days" +%F)

# Convenient vars for loops (the 10# strips leading zeros)
numbeg=$(($(date -d "$daybeg" +%Y)*12 + 10#$(date -d "$daybeg" +%m) - 1))
numend=$(($(date -d "$dayend" +%Y)*12 + 10#$(date -d "$dayend" +%m) - 1))

# For post-processing utilities
PPARGS=("--prod" "$PROD" "--ver" "$VER" "--res" "$RES" "--input" "$DIRDATA" \
    "--output" "$DIRDATA" "--batch")
[[ "$FORCE" == true ]] && PPARGS+=("--force")

# Need to be split so it doesn't try to retrieve NRT MODIS collections
modvir vegind --mode regrid --beg "$daybeg" --end "$dayend" "${MVARGS[@]}"
modvir vegind --mode fill   --beg "$daybe4" --end "$dayend" "${MVARGS[@]}"
# Different processing of NRT biomass burning
if [[ "$VER" == "NRT" ]]; then
    (
        cd "$CASADIR" || exit
        # Need to be careful with this, bash will expand things like *
        $MATLAB -r "DIRDATA = '$DIRDATA'; makeNRTburn; exit"
        cd - > /dev/null || exit
    )
else
    modvir burn --mode regrid --beg "$daybeg" --end "$dayend" "${MVARGS[@]}"
fi

# Post-process drivers
for num in $(seq $numbeg $numend); do
    year=$((num/12))
    mon=$((num - year*12 + 1))

    "$CASADIR/utils/post/drivers.sh" $year --mon $mon "${PPARGS[@]}"
done

# Run CASA
# ---
(
    # Remove previous forecast so we write w/o force
    [[ "$VER" == "NRT" ]] && "$CASADIR/utils/post/forecast.sh" "$daybe4" \
        "${PPARGS[@]}" --clean

    cd "$CASADIR" || exit
    # Add an extra convertOutput at the end in case we complete a month
    # Need to be careful with this, bash will expand things like *
    RUNCMDS="runname = 'v$VER'; DIRDATA = '$DIRDATA'; CASA; convertOutput; \
        lofi.make_sink; lofi.make_3hrly_land; convertOutput; exit"
    $MATLAB -r "$RUNCMDS"
    cd - > /dev/null || exit
)

# Post-process fluxes
for num in $(seq $numbeg $numend); do
    year=$((num/12))
    mon=$((num - year*12 + 1))

    QQARGS=("${PPARGS[@]}")
    # NRT MUST REPROCESS because forecast creates future files and
    # will complete monthlies with those files
    [[ "$VER" == "NRT" ]] && QQARGS+=("--force")
    "$CASADIR/utils/post/process.sh" $year --mon "$mon" "${QQARGS[@]}"
done

# Forecast
# ---
[[ "$VER" == "NRT" ]] && "$CASADIR/utils/post/forecast.sh" "$dayend" "${PPARGS[@]}"
