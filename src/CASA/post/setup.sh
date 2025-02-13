#!/bin/bash

# Run-specific settings
# ---
# Needs serious improvement (***FIXME***)
# Thought is that there would be a utility that reads run settings (perhaps in
# a yaml file) and sets environment variabiles. Then Python, Matlab, and Bash
# would be able to read these variables from a consistent place.
[[ -z "$REPRO" ]] && REPRO=false
[[ -z "$REPROCOG" ]] && REPROCOG=false
[[ -z "$MIDIR" ]] && MIDIR="~/Projects/MiCASA"

if [[ "$MIRUN" == "vNRT/daily-0.1deg" ]]; then
    VERSION="NRT"
    ROOTOUT="/css/gmao/geos_carb/share"
else
    VERSION="1"
    ROOTOUT="/css/gmao/geos_carb/pub"
fi
DIRIN="$MIDIR/data-casa/v$VERSION/daily-0.1deg/holding"

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

# Dataportal
SERVE="https://portal.nccs.nasa.gov/datashare/gmao/geos_carb"

# Load NCO utilities on Discover
# ---
source "$LMOD_PKG"/init/bash
# Worthwhile to keep a record, but modules aren't consistent across discover
# nodes, especially over OS updates
#module load nco/5.1.4						# Value used for v1
module load nco
