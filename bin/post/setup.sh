#!/bin/bash

# I'd really like to read these somewhere central
VERSION="1"
COLTAG="MiCASA_v${VERSION}_flux_x3600_y1800"
RESTAG="0.1 degree x 0.1 degree"
FEXT="nc4"

# I'd really like to send these as commands
REPRO=false
REPROCOG=false

# System-specific settings
# ---
# 1. Input
DIRIN="/discover/nobackup/bweir/MiCASA/data-casa/daily-0.1deg-new/holding"

# 2. Output
ROOTOUT="/discover/nobackup/projects/gmao/geos_carb/pub"
HEADOUT="MiCASA/v$VERSION/netcdf"
DIROUT="$ROOTOUT/$HEADOUT"					# Form needed for URLs
HEADDOC="MiCASA/v$VERSION"					# Form needed for URLs

# 3. COG
HEADCOG="MiCASA/v$VERSION/cog"
DIRCOG="$ROOTOUT/$HEADCOG"					# Copying netCDF form

# 4. Dataportal
SERVE="https://portal.nccs.nasa.gov/datashare/gmao/geos_carb"

# Load NCO utilities on Discover
# ---
source "$LMOD_PKG"/init/bash
module load nco/5.1.4
