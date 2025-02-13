#!/bin/bash

echo "---"
echo "MiCASA validation check" 
echo "---"

#DIRCHECK="/discover/nobackup/projects/gmao/geos_carb/pub/MiCASA/v1/netcdf"
DIRCHECK="/css/gmao/geos_carb/pub/MiCASA/v1/netcdf"

#DAYSIZE="129645896c"
#MONSIZE="129646112c"
DAYSIZE="129645892c"
MONSIZE="129646108c"

find $DIRCHECK/daily   -name "*.nc" ! -size "$DAYSIZE"
find $DIRCHECK/monthly -name "*.nc" ! -size "$MONSIZE"

#find $DIRCHECK -name "*_sha256.txt" -exec shasum -a 256 -c {} \;
find $DIRCHECK -name "*_sha256.txt" -exec echo {} \;
