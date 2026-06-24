#!/usr/bin/env bash

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

# Public URL and on-prem directories
SERVE="https://portal.nccs.nasa.gov/datashare/gmao/geos_carb"

# Half-generic settings
# ---
# These should be better protected against something else defining them
MIROOT=${MIROOT:-"$HOME/Projects/MiCASA"}
ROOTPUB=${ROOTPUB:-"/css/gmao/geos_carb/pub/MiCASA"}

FEXT="nc4"

# Get and check arguments
# ---
usage() {
    echo "usage: $1 [-h] [-m MON] [-p PROD] [-v VER] [-r RES] [-f] [-b] year"
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

    year="${POSARGS[0]}"
    if [[ "${#POSARGS[@]}" -lt 1 || "$year" -lt 1000 || 3000 -lt "$year" ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: invalid year $year" >&2
        exit 1
    fi

    DINFLX="$MIROOT/data/v$VER/netcdf"
    DINDRV="$MIROOT/data/v$VER/drivers"
    DOUTFLX="$ROOTPUB/v$VER/netcdf"
    DOUTDRV="$ROOTPUB/v$VER/drivers"
    DOUTCOG="$ROOTPUB/v$VER/cog"

    HEADFLX="${PROD}_v${VER}_flux_$RES"

    CPCMD="rsync"
    CPARGS=("-av" "-R")
    $FORCE || CPARGS+=("--ignore-existing")
}
