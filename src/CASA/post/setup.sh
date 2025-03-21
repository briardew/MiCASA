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
SERVE="https://portal.nccs.nasa.gov/datashare/gmao/geos_carb"
#ROOTPUB="/css/gmao/geos_carb/pub"
#ROOTNRT="/css/gmao/geos_carb/share"
ROOTPUB="/discover/nobackup/projects/gmao/geos_carb/share"
ROOTNRT="/discover/nobackup/projects/gmao/geos_carb/share"

# Rest should be generic
# ---
if [[ "$MIRUN" == "vNRT" ]]; then
    VERSION="NRT"
    ROOTOUT="$ROOTNRT"
    # We need this for now: 1) Forecast creates files that need to be
    # overwritten and 2) Monthly means will be computed when the *forecast*
    # completes the month; so they need to be overwritten too. Biggest
    # downside is reprocessing a year takes A LOT of time; maybe move
    # process.sh
    REPRO=true
else
    VERSION="1"
    ROOTOUT="$ROOTPUB"
fi

[[ -z "$MIDIR" ]] && MIDIR="$HOME/Projects/MiCASA"
[[ -z "$REPRO" ]] && REPRO=false
[[ -z "$REPROCOG" ]] && REPROCOG=false

DIRIN="$MIDIR/data/v$VERSION/holding"

# The rest should auto-generate
# ---
COLTAG="MiCASA_v${VERSION}_flux_x3600_y1800"
RESTAG="0.1 degree x 0.1 degree"
FEXT="nc4"

# Output
HEADOUT="MiCASA/v$VERSION/netcdf"
DIROUT="$ROOTOUT/$HEADOUT"					# Form needed for URLs
HEADDOC="MiCASA/v$VERSION"					# Form needed for URLs

# COG
HEADCOG="MiCASA/v$VERSION/cog"
DIRCOG="$ROOTOUT/$HEADCOG"					# Copying netCDF form
