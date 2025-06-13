#!/bin/bash

echo "---"
echo "MiCASA validation check" 
echo "---"

#DIRCHECK="/discover/nobackup/projects/gmao/geos_carb/pub/MiCASA/v1/netcdf"
DIRCHECK="/css/gmao/geos_carb/pub/MiCASA/v1/netcdf"

while read -r ff; do
    (
    cd "$(dirname "$ff")" || exit
    shasum -a 256 -c "$ff" || exit
    )
done <<< "$(find "$DIRCHECK" -name "*_sha256.txt")"
