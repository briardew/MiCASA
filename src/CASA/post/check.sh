#!/bin/bash

echo "---"
echo "MiCASA validation check" 
echo "---"

#DIRCHECK="/discover/nobackup/projects/gmao/geos_carb/pub/MiCASA/v1/netcdf"
DIRCHECK="/css/gmao/geos_carb/pub/MiCASA/v1/netcdf"

#find $DIRCHECK -name "*_sha256.txt" -exec shasum -a 256 -c {} \;
find $DIRCHECK -name "*_sha256.txt" -exec echo {} \;
