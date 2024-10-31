#!/bin/bash

TAG="nbe_conus"

source /etc/profile.d/lmod.sh
module load ffmpeg

# Filters:
# 1. scale=trunc(iw/2)*2:trunc(ih/2)*2 makes the height and width even
# 2. setpts=PTS*2 slows down the movie by a factor of 2
ffmpeg -pattern_type glob -i "${TAG}_*.png" \
    -c:v libx264 -pix_fmt yuv420p \
    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2, setpts=PTS*2" "$TAG.mp4"
