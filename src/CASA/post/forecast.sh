#!/usr/bin/env bash

# Brutal hack to persist for a specified number of days. Hope is to actually do
# something scientifically defensible. Expect this script and its use to be
# volatile.

BLURB="MiCASA flux forecasting" 
# Default forecast length in days
NDAYSDEF=14

# Process settings
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR"/setup.sh

# Redefine the default argument parsing with our own
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
    echo "  -p PROD, --prod PROD  product name (default: MiCASA)"
    echo "  -v VER, --ver VER     version (default: NRT)"
    echo "  -r RES, --res RES     resolution (default: x3600_y1800)"
    echo "  -i DIR, --input DIR   input root directory (default: $ROOTDEF)"
    echo "  -o DIR, --output DIR  output root directory (default: $ROOTDEF)"
    echo "  -b, --batch           operate in batch mode (default: False)"
}

argparse() {
    # Defaults
    PROD="MiCASA"
    VER="NRT"
    RES="x3600_y1800"
    ROOTIN=$ROOTDEF
    ROOTOUT=$ROOTDEF
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
                ROOTIN="$2"
                shift 2
                ;;
            -o|--output)
                ROOTOUT="$2"
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
    DAYBEG=$(date -d "${POSARGS[0]}" +%F)

    NDAYS=${POSARGS[1]:-$NDAYSDEF}
    if [[ "$NDAYS" -le 0 || 366 -gt "$NDAYS" ]]; then
        echo "$MYNAME: warning: '$NDAYS' is out of range. Setting to $NDAYSDEF"
        NDAYS=$NDAYSDEF
    fi

    # Define derived variables
    # ---
    DINFLX="$ROOTIN/v$VER/netcdf"
    DOUTFLX="$ROOTOUT/v$VER/netcdf"
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
