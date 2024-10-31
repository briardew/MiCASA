#!/bin/bash

# Starting with 1km files to minimize interpolation errors
vars=('bdod' 'cfvo' 'soc' 'clay' 'silt' 'sand')
depths=('0-5cm' '5-15cm' '15-30cm' '30-60cm' '60-100cm')

for vv in ${vars[@]}; do
    for dd in ${depths[@]}; do
        ff=${vv}_${dd}_mean_1000.tif
#       wget -nc -c --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 \
#           "https://files.isric.org/soilgrids/latest/data_aggregated/1000m/$vv/$ff"
#
#       fout=$(basename $ff _1000.tif)_0.01x0.01.tif
#       gdalwarp -t_srs EPSG:4326 -te -180 -56 180 83 -tr 0.01 0.01 $ff $fout

        fout=$(basename $ff _1000.tif)_0.1x0.1.tif
        gdalwarp -t_srs EPSG:4326 -te -180 -56 180 83 -tr 0.1 0.1 $ff $fout
    done
done
