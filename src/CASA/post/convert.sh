#!/bin/bash

REPRO=true
YEAR0=2001
YEARF=2024

RESTAG="0.5 degree x 0.5 degree"
XIN=3600
YIN=1800
XOUT=720
YOUT=360
VERSION="1"

GRIDIN="x${XIN}_y${YIN}"
GRIDOUT="x${XOUT}_y${YOUT}"

DIRIN="/css/gmao/geos_carb/pub/MiCASA/v$VERSION/netcdf"
DIROUT="/css/gmao/geos_carb/pub/MiCASA/v$VERSION/netcdf-0.5deg"

# RUN
module load nco
OMP_NUM_THREADS=40
[[ "$REPRO" == true ]] && echo "WARNING: Reprocessing, will overwrite files ..." 1>&2

if [[ ! -f "map_${GRIDIN}_to_${GRIDOUT}.nc" ]]; then
    ncremap -g "grid_$GRIDIN.nc"  -G latlon="$YIN","$XIN"#lon_typ=180_wst
    ncremap -g "grid_$GRIDOUT.nc" -G latlon="$YOUT","$XOUT"#lon_typ=180_wst
    ncremap -s "grid_$GRIDIN.nc" -g "grid_$GRIDOUT.nc" -m "map_${GRIDIN}_to_${GRIDOUT}.nc"
fi

for year in $(seq "$YEAR0" "$YEARF"); do
    echo $year
    for mon in $(seq -w 01 12); do
        # 3-hourly
        timespan="3-hourly"
        fhead="$DIRIN/3hrly/$year/$mon/MiCASA_v${VERSION}_flux_${GRIDIN}_3hrly_$year$mon"
        for fin in "$fhead"??.nc4; do
            fout="$(echo "$fin" | sed -e "s?$GRIDIN?$GRIDOUT?" | sed -e "s?$DIRIN?$DIROUT?")"

            [[ "$REPRO" != true && -f "$fout" ]] && continue

            echo "Converting $fin to $fout ..."
            mkdir -p "$DIROUT/3hrly/$year/$mon"
            ncremap -n -h -m "map_${GRIDIN}_to_${GRIDOUT}.nc" "$fin" "$fout"
            ncatted -O -h -a title,global,o,c,"MiCASA $timespan NPP NEE Fluxes $RESTAG v$VERSION" "$fout"
            ncatted -O -h -a LongName,global,o,c,"MiCASA $timespan NPP NEE Fluxes $RESTAG" "$fout"
            ncatted -O -h -a remap_hostname,global,d,, "$fout"
            ncatted -O -h -a input_file,global,d,, "$fout"
            hisout="ncremap -m map_${GRIDIN}_to_${GRIDOUT}.nc $(basename "$fin") $(basename "$fout")"
            ncatted -O -h -a history,global,o,c,"$hisout" "$fout"
            ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"
        done

        # Daily
        timespan="Daily"
        fhead="$DIRIN/daily/$year/$mon/MiCASA_v${VERSION}_flux_${GRIDIN}_daily_$year$mon"
        for fin in "$fhead"??.nc4; do
            fout="$(echo "$fin" | sed -e "s?$GRIDIN?$GRIDOUT?" | sed -e "s?$DIRIN?$DIROUT?")"

            [[ "$REPRO" != true && -f "$fout" ]] && continue

            echo "Converting $fin to $fout ..."
            mkdir -p "$DIROUT/daily/$year/$mon"
            ncremap -n -h -m "map_${GRIDIN}_to_${GRIDOUT}.nc" "$fin" "$fout"
            ncatted -O -h -a title,global,o,c,"MiCASA $timespan NPP NEE Fluxes $RESTAG v$VERSION" "$fout"
            ncatted -O -h -a LongName,global,o,c,"MiCASA $timespan NPP NEE Fluxes $RESTAG" "$fout"
            ncatted -O -h -a remap_hostname,global,d,, "$fout"
            ncatted -O -h -a input_file,global,d,, "$fout"
            hisout="ncremap -m map_${GRIDIN}_to_${GRIDOUT}.nc $(basename "$fin") $(basename "$fout")"
            ncatted -O -h -a history,global,o,c,"$hisout" "$fout"
            ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"
        done

        # Monthly
        timespan="Monthly"
        fin="$DIRIN/monthly/$year/MiCASA_v${VERSION}_flux_${GRIDIN}_monthly_$year$mon.nc4"
        fout="$(echo "$fin" | sed -e "s?$GRIDIN?$GRIDOUT?" | sed -e "s?$DIRIN?$DIROUT?")"

        [[ "$REPRO" != true && -f "$fout" ]] && continue

        echo "Converting $fin to $fout ..."
        mkdir -p "$DIROUT/monthly/$year"
        ncremap -n -h -m "map_${GRIDIN}_to_${GRIDOUT}.nc" "$fin" "$fout"
        ncatted -O -h -a title,global,o,c,"MiCASA $timespan NPP NEE Fluxes $RESTAG v$VERSION" "$fout"
        ncatted -O -h -a LongName,global,o,c,"MiCASA $timespan NPP NEE Fluxes $RESTAG" "$fout"
        ncatted -O -h -a remap_hostname,global,d,, "$fout"
        ncatted -O -h -a input_file,global,d,, "$fout"
        hisout="ncremap -m map_${GRIDIN}_to_${GRIDOUT}.nc $(basename "$fin") $(basename "$fout")"
        ncatted -O -h -a history,global,o,c,"$hisout" "$fout"
        ncatted -O -h -a ProductionDateTime,global,o,c,"$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$fout"
    done
done
