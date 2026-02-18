#!/bin/bash

# NCCS Discover specific settings
# ---
# NCO utilities
source "$LMOD_PKG"/init/bash
# Worthwhile to keep a record, but modules aren't consistent across
# NCCS Discover nodes, especially over OS updates
#module load nco/5.1.4						# Value used for v1
module load nco

# Public URL and on-prem directories
# ---
SERVE="https://portal.nccs.nasa.gov/datashare/gmao/geos_carb"
ROOTOUT="/discover/nobackup/projects/gmao/geos_carb/share"
ROOTPUB="/css/gmao/geos_carb/pub"

# Half-generic settings
# ---
# These should be better protected against something else defininit them
[[ -z "$MIROOT" ]]  && MIROOT="$HOME/Projects/MiCASA"
[[ -z "$VERSION" ]] && VERSION="NRT"

# Run specific settings
# ---
RESLONG="0.1 degree x 0.1 degree"
RESTAG="x3600_y1800"
FLXTAG="MiCASA_v${VERSION}_flux_${RESTAG}"
FEXT="nc4"

# The rest should auto-generate
# ---
DIRIN="$MIROOT/data/v$VERSION/holding"
VEGIN="$MIROOT/data/v$VERSION/drivers"

# Output (fluxes)
HEADOUT="MiCASA/v$VERSION/netcdf"
DIROUT="$ROOTOUT/$HEADOUT"					# Form needed for URLs
HEADDOC="MiCASA/v$VERSION"					# Form needed for URLs

# COG
HEADCOG="MiCASA/v$VERSION/cog"
DIRCOG="$ROOTPUB/$HEADCOG"					# Copying netCDF form

# Drivers
HEADVEG="MiCASA/v$VERSION/drivers"
DIRVEG="$ROOTPUB/$HEADVEG"					# Form needed for URLs

# Get and check arguments
# ---
usage() {
    echo "usage: $1 year [options]"
    echo ""
    echo "$2"
    echo ""
    echo "positional arguments:"
    echo "  year               4-digit year to process"
    echo ""
    echo "options:"
    echo "  -h, --help         show this help message and exit"
    echo "  -m MON, --mon MON  only process month MON (default: None)"
    echo "  -v VER, --ver VER  version (default: $VERSION)"
    echo "  -f, --force        overwrite files (default: False)"
    echo "  -b, --batch        operate in batch mode (default: False)"
}

argparse() {
    # Defaults
    MON0=01
    MONF=12
    FORCE=false
    BATCH=false

    year="$3"
    if [[ "$year" == "-h" || "$year" == "--help" ]]; then
        usage "$1" "$2"
        exit
    elif [[ "$#" -lt 1 || "$year" -lt 1000 || 3000 -lt "$year" ]]; then
        echo "ERROR: Invalid year $year"
        echo ""
        usage "$1" "$2"
        exit 1
    fi

    ii=4
    while [[ "$ii" -le "$#" ]]; do
        arg="${@:$ii:1}"
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            usage "$1" "$2"
            exit
        elif [[ "$arg" == "-m" || "$arg" == "--mon" ]]; then
            ii=$((ii+1))
            mon="${@:$ii:1}"
            # Force base 10 interpretation of 08 and 09
            if [[ "$((10#$mon))" -lt 1 || 12 -lt "$((10#$mon))" ]]; then
                echo "ERROR: Invalid month $mon"
                echo ""
                usage "$1" "$2"
                exit 1
            fi
            MON0=$(printf %02g "$mon")
            MONF=$(printf %02g "$mon")
        elif [[ "$arg" == "-v" || "$arg" == "--ver" ]]; then
            ii=$((ii+1))
            VERSION="${@:$ii:1}"
        elif [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
            FORCE=true
        elif [[ "$arg" == "-b" || "$arg" == "--batch" ]]; then
            BATCH=true
        elif [[ "$arg" == "-fb" || "$arg" == "-bf" ]]; then
            FORCE=true
            BATCH=true
        else
            echo "ERROR: Invalid $ii-th argument $arg"
            echo ""
            usage "$1" "$2"
            exit 1
        fi
        ii=$((ii+1))
    done
}
