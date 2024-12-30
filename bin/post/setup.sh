#!/bin/bash

# Run-specific settings
# (needs serious improvement, ***FIXME***)
# ---
VERSION="1"
DIRIN="/discover/nobackup/bweir/MiCASA/data-casa/daily-0.1deg/holding"
ROOTOUT="/css/gmao/geos_carb/pub"
#VERSION="NRT"
#DIRIN="/discover/nobackup/ghg_ops/MiCASA/data-casa/daily-0.1deg-nrt/holding"
#ROOTOUT="/css/gmao/geos_carb/share"

# I'd really like to send these as commands
REPRO=false
REPROCOG=false

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
module load nco/5.1.4
