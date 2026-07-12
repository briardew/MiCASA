#!/usr/bin/env bash

# Brutal hack for now to persist for a specified number of days. Hope is to actually do
# something scientifically defensible. Add a climatological "velocity"? ML emulator?
# Note: Even if you had a met forecast, you don't have a VI and BA forecast.
# It may be better to try to train a forecast of MET -> BA, VI or MET, C0 -> PP, ER?

BLURB="MiCASA flux forecasting" 
# Default forecast length in days
NDAYSDEF=14

# Process settings
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR/../../setup.sh"

# Redefine the default argument parsing
# ---
usage() {
    echo "usage: $1 [-h] [-p PROD] [-v VER] [-r RES] [-i DIR] [-o DIR] [-b]" \
        "date [ndays]"
}

helpout() {
    echo "$1"
    echo ""
    echo "positional arguments:"
    echo "  date                  begin date as YYYY-MM-DD"
    echo "  ndays                 forecast length in days (default: 14)"
    echo ""
    echo "options:"
    echo "  -h, --help            show this help message and exit"
    echo "  -p PROD, --prod PROD  product name (default: $PRODDEF)"
    echo "  -v VER, --ver VER     version (default: $VERDEF)"
    echo "  -r RES, --res RES     resolution (default: $RESDEF)"
    echo "  -i DIR, --input DIR   input root directory (default: $DATADEF)"
    echo "  -o DIR, --output DIR  output root directory (default: $DATADEF)"
    echo "  -b, --batch           operate in batch mode (default: False)"
}

argparse() {
    # Defaults
    PROD=$PRODDEF
    VER=$VERDEF
    RES=$RESDEF
    DATAIN=$DATADEF
    DATAOUT=$DATADEF
    FORCE=true
    BATCH=false

    # First two args are for help
    MYNAME="$1"
    BLURB="$2"
    shift 2

    POSARGS=()

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
            -b|--batch)
                BATCH=true
                shift
                ;;
            -i|--input)
                DATAIN="$2"
                shift 2
                ;;
            -o|--output)
                DATAOUT="$2"
                shift 2
                ;;
            -h|--help)
                usage "$MYNAME"
                echo ""
                helpout "$BLURB"
                exit
                ;;
            -*)
                usage "$MYNAME" >&2
                echo "$MYNAME: error: unknown option $1" >&2
                exit 1
                ;;
            # Handle positional arguments (arguments without flags)
            *)
                POSARGS+=("$1")
                shift
                ;;
        esac
    done

    # Get and check start date ($DAYBEG) and forecast length ($NDAYS)
    # ---
    if [[ ${#POSARGS[@]} -eq 0 ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: the following arguments are required: date" >&2
        exit 1
    fi
    if ! DAYBEG=$(date -d "${POSARGS[0]}" +%F); then
        usage "$MYNAME" >&2
        exit 1
    fi

    NDAYS=${POSARGS[1]:-$NDAYSDEF}
    if [[ "$NDAYS" -le 0 || 366 -gt "$NDAYS" ]]; then
        echo "$MYNAME: warning: '$NDAYS' is out of range. Setting to $NDAYSDEF"
        NDAYS=$NDAYSDEF
    fi

    # Define derived variables
    # ---
    DINFLX="$DATAIN/v$VER/netcdf"
    DOUTFLX="$DATAOUT/v$VER/netcdf"
    HEADFLX="${PROD}_v${VER}_flux_$RES"
}

# Process arguments
# ---
argparse "$(basename "$0")" "$BLURB" "$@"

# Outputs and warnings
# ---
echo "---"
echo "$BLURB"
echo "---"
echo "Input location: $DOUTFLX"
echo "Output location: $DOUTFLX"
echo "Collection: $HEADFLX"
echo "Start date: $DAYBEG"
echo "Num days: $NDAYS"

warnings

echo ""

# Run
# ---
year=$(date -d "$DAYBEG" +%Y)
mon=$(date -d "$DAYBEG" +%m)
day=$(date -d "$DAYBEG" +%d)

ff="${HEADFLX}_3hrly_$year$mon$day.$FEXT"
f3hr="$DINFLX/3hrly/$year/$mon/$ff"
# Exit if 3hrly file is missing
if [[ ! -f "$f3hr" ]]; then
    echo "ERROR: 3-hourly file for $DAYBEG is missing:" >&2
    echo "$f3hr" >&2
    exit 1
fi

ff="${HEADFLX}_daily_$year$mon$day.$FEXT"
fday="$DINFLX/daily/$year/$mon/$ff"
# Exit if daily file is missing
if [[ ! -f "$fday" ]]; then
    echo "ERROR: Daily file for $DAYBEG is missing:" >&2
    echo "$fday" >&2
    exit 1
fi

for num in $(seq 1 "$NDAYS"); do
    daynow=$(date -d "$DAYBEG +$num days" +%F)
    year=$(date -d "$daynow" +%Y)
    mon=$(date -d "$daynow" +%m)
    day=$(date -d "$daynow" +%d)

    ff="${HEADFLX}_3hrly_$year$mon$day.$FEXT"
    mkdir -p "$DOUTFLX/3hrly/$year/$mon"
    fout="$DOUTFLX/3hrly/$year/$mon/$ff"
    echo "Writing $fout ..."
    ncap2 -O -s "time=time+$num;time_bnds=time_bnds+$num" "$f3hr" "$fout"

    ff="${HEADFLX}_daily_$year$mon$day.$FEXT"
    mkdir -p "$DOUTFLX/daily/$year/$mon"
    fout="$DOUTFLX/daily/$year/$mon/$ff"
    echo "Writing $fout ..."
    ncap2 -O -s "time=time+$num;time_bnds=time_bnds+$num" "$fday" "$fout"
done
