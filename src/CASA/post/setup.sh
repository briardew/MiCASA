#!/usr/bin/env bash

# Defaults
ROOTDEF="$HOME/Projects/MiCASA/data"
FEXT="nc4"

# Be strict about errors
set -euo pipefail

# NCCS Discover specific settings
# ---
# NCO utilities
source "$LMOD_PKG"/init/bash
# Worthwhile to keep a record, but modules aren't consistent across
# NCCS Discover nodes, especially over OS updates
#module load nco/5.1.4						# Value used for v1
module load nco

# Get and check arguments
# ---
usage() {
    echo "usage: $1 [-h] [-m MON] [-p PROD] [-v VER] [-r RES] [-i DIR] [-o DIR]" \
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
    echo "  -m MON, --mon MON     only process month MON (default: None)"
    echo "  -p PROD, --prod PROD  product name (default: MiCASA)"
    echo "  -v VER, --ver VER     version (default: NRT)"
    echo "  -r RES, --res RES     resolution (default: x3600_y1800)"
    echo "  -i DIR, --input DIR   input root directory (default: $ROOTDEF)"
    echo "  -o DIR, --output DIR  output root directory (default: $ROOTDEF)"
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
        read -n1 -s -r -p $"Press any key to continue ..." unused
        echo ""
    fi
}

argparse() {
    # Defaults
    MON0=1
    MONF=12
    PROD="MiCASA"
    VER="NRT"
    RES="x3600_y1800"
    ROOTIN=$ROOTDEF
    ROOTOUT=$ROOTDEF
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
                ROOTIN="$2"
                shift 2
                ;;
            -o|--output)
                ROOTOUT="$2"
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
    if [[ "${#POSARGS[@]}" -lt 1 || "$year" -lt 1000 || 3000 -lt "$year" ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: argument year: invalid choice: \'$year\'" >&2
        exit 1
    fi

    # Define derived variables
    # ---
    DINFLX="$ROOTIN/v$VER/netcdf"
    DINDRV="$ROOTIN/v$VER/drivers"
    DOUTFLX="$ROOTOUT/v$VER/netcdf"
    DOUTDRV="$ROOTOUT/v$VER/drivers"
    DOUTCOG="$ROOTOUT/v$VER/cog"

    HEADFLX="${PROD}_v${VER}_flux_$RES"

    CPCMD="rsync"
    CPARGS=("-av" "-R")
    $FORCE || CPARGS+=("--ignore-existing")
}

# Mostly so shellcheck won't complain
debugargs() {
    echo "MON0 = $MON0"
    echo "MONF = $MONF"
    echo "DINFLX = $DINFLX"
    echo "DINDRV = $DINDRV"
    echo "DOUTFLX = $DOUTFLX"
    echo "DOUTDRV = $DOUTDRV"
    echo "DOUTCOG = $DOUTCOG"
    echo "HEADFLX = $HEADFLX"
    echo "CPCMD = $CPCMD"
    echo "CPARGS =" "${CPARGS[@]}"
}
