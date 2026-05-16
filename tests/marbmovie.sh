#!/bin/bash

#DAY0="2023-12-31"	# Day before first day
#NDAYS="160"

DAY0="2018-12-31"	# Day before first day
NDAYS="60"

for nn in $(seq 1 $NDAYS); do
    dd=$(date -d "$DAY0 +$nn days" +%Y%m%d)
    convert figs/marb_$dd.png -crop 4200x2200+320+600 +repage figs/top.png
    convert figs/flux_$dd.png -crop 4200x2350+320+600 +repage figs/bot.png
    convert figs/top.png figs/bot.png -append figs/frame_$dd.png
done
rm figs/top.png figs/bot.png

source /etc/profile.d/lmod.sh
module load ffmpeg

ffmpeg -pattern_type glob -i "figs/frame_*.png" \
    -c:v libx264 -pix_fmt yuv420p -filter:v "setpts=3*PTS" micasa-marb.mp4
