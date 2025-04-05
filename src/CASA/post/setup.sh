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
[[ -z "$MIROOT" ]] && MIROOT="$HOME/Projects/MiCASA"
[[ -z "$VERSION" ]] && VERSION="NRT"
[[ -z "$REPRO" ]] && REPRO=false
[[ -z "$REPROCOG" ]] && REPROCOG=false

if [[ "$VERSION" == "NRT" ]]; then
    ROOTOUT="$ROOTNRT"
else
    ROOTOUT="$ROOTPUB"
fi

DIRIN="$MIROOT/data/v$VERSION/holding"

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
