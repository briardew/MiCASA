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
[[ -z "$MIROOT" ]] && MIROOT="$HOME/Projects/MiCASA"
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
