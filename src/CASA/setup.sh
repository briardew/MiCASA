#!/usr/bin/env bash

# Be strict about errors
# Note: This is turned off at the end and must be added at the top of each script.
# Otherwise, sourcing from an interactive shell will keep it on for the shell, which
# will cause it to exit on any error.
set -euo pipefail

# Initialize environment
# ---
# This initialization:
#     1) Defines a collection of hosts to distribute jobs over,
#     2) Activates the Python stack where MiCASA is installed,
#     3) Loads NCO and Matlab/Octave
# Theoretically, it's possible to do this all in .bashrc, but at least on NCCS Discover
# we don't (yet). This adds a bit of system dependence, but it seems fine.

if [[ "$HOSTNAME" =~ discover* || "$HOSTNAME" =~ borg* || "$HOSTNAME" =~ warp* ]]; then
   SITE="NCCS"
else
   SITE="$HOSTNAME"
fi

if [[ "$SITE" == "NCCS" ]]; then
    # 1) Define hosts to distribute jobs over
    HOSTS=("discover31" "discover32" "discover33" "discover34" \
        "discover35" "discover36")

    # 2) Activate Python stack
    eval "$(conda shell.bash hook)"
    conda activate

    # 3) Load NCO and Matlab/Octave
    # NCO & Matlab/Octave environment variables
    # (Worthwhile to keep a record, but modules aren't consistent across OS versions)
    #module load nco/5.1.4						# Value used for v1
    #module load matlab/R2020a						# Value used for v1?
    module load nco
    module load matlab
    # Redefine Matlab license
    export MLM_LICENSE_FILE="27000@ace64:28000@ls1,28000@ls2,28000@ls3"
    MATLAB="matlab -nosplash -nodesktop"
else
    # You're on your on here bud
    HOSTS=("$HOSTNAME")
    MATLAB="matlab -nosplash -nodesktop"
fi

# Get and check arguments
# ---
# Defaults
PRODDEF="MiCASA"
VERDEF="NRT"
LATENCY="2"								# Latency in number of days
RESDEF="x3600_y1800"
ROOTDEF=$(realpath -s "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../..")
DATADEF="$ROOTDEF/data"
FEXT="nc4"
COLSOUT=("flux" "extra" "fire")						# Output collections
COLSPUB=("flux")							# Public collections

usage() {
    echo "usage: $1 [-h] [-p PROD] [-v VER] [-r RES] [-m MON] [-i DIR] [-o DIR]" \
        "[-f] [-b] year"
}

helpout() {
    echo "$1"
    echo ""
    echo "positional arguments:"
    echo "  year                  4-digit year to process"
    echo ""
    echo "options:"
    echo "  -h, --help            show this help message and exit"
    echo "  -p PROD, --prod PROD  product name (default: $PRODDEF)"
    echo "  -v VER, --ver VER     version (default: $VERDEF)"
    echo "  -r RES, --res RES     resolution (default: $RESDEF)"
    echo "  -m MON, --mon MON     only process month MON (default: None)"
    echo "  -i DIR, --input DIR   input root directory (default: $DATADEF)"
    echo "  -o DIR, --output DIR  output root directory (default: $DATADEF)"
    echo "  -f, --force           overwrite files (default: False)"
    echo "  -b, --batch           operate in batch mode (default: False)"
}

warnings() {
    if [[ "$FORCE" == true ]]; then
        echo ""
        echo "WARNING: Overwriting existing files ..."
    fi

    # Give a chance to abort
    if [[ "$BATCH" != true ]]; then
        echo ""
        # shellcheck disable=SC2034
        read -n1 -s -r -p $"Press any key to continue ..." unused
        echo ""
    fi
}

argparse() {
    # Defaults
    MON0=1
    MONF=12
    PROD=$PRODDEF
    VER=$VERDEF
    RES=$RESDEF
    DATAIN=$DATADEF
    DATAOUT=$DATADEF
    FORCE=false
    BATCH=false

    # First two args are for help
    MYNAME="$1"
    BLURB="$2"
    shift 2

    POSARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--mon)
                # Force base 10 interpretation of 08 and 09
                mon="$((10#$2))"
                if [[ $mon -lt 1 || 12 -lt $mon ]]; then
                    usage "$MYNAME" >&2
                    echo "$MYNAME: error: invalid month $mon" >&2
                    exit 1
                fi
                MON0=$mon
                MONF=$mon
                shift 2
                ;;
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
            -i|--input)
                DATAIN="$2"
                shift 2
                ;;
            -o|--output)
                DATAOUT="$2"
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

    # Get and check year
    # ---
    if [[ ${#POSARGS[@]} -eq 0 ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: the following arguments are required: year" >&2
        exit 1
    fi
    year="${POSARGS[0]}"
    if [[ "$year" -lt 1000 || 3000 -lt "$year" ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: argument year: invalid choice: \'$year\'" >&2
        exit 1
    fi

    # Define derived variables
    # ---
    DINFLX="$DATAIN/v$VER/netcdf"
    DINDRV="$DATAIN/v$VER/drivers"
    DOUTFLX="$DATAOUT/v$VER/netcdf"
    DOUTDRV="$DATAOUT/v$VER/drivers"
    DOUTCOG="$DATAOUT/v$VER/cog"

    CPCMD="rsync"
    CPARGS=("-av" "-R")
    $FORCE || CPARGS+=("--ignore-existing")
}

# Mostly so shellcheck won't complain, but could come in handy
argdebug() {
    echo "HOSTS =" "${HOSTS[@]}"
    echo "MATLAB = $MATLAB"
    echo "MON0 = $MON0"
    echo "MONF = $MONF"
    echo "PROD = $PROD"
    echo "RES = $RES"
    echo "DINFLX = $DINFLX"
    echo "DINDRV = $DINDRV"
    echo "DOUTFLX = $DOUTFLX"
    echo "DOUTDRV = $DOUTDRV"
    echo "DOUTCOG = $DOUTCOG"
    echo "COLSOUT = ${COLSOUT[*]}"
    echo "COLSPUB = ${COLSPUB[*]}"
    echo "LATENCY = $LATENCY"
    echo "FEXT = $FEXT"
    echo "CPCMD = $CPCMD"
    echo "CPARGS = ${CPARGS[*]}"
}

set +euo pipefail
