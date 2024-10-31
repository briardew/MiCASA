#!/bin/bash

# discover11-14, 21-24
# discover22,24,31,32 are slow

# 2024: discover23
for year in {2024..2024}; do
    ssh discover23 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/vegpre/${year}a
        cd logs/vegpre/${year}a
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode regrid --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover23 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/vegpre/${year}b
        cd logs/vegpre/${year}b
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode regrid --beg $year-07-01 --end $year-12-31\"
        exit"
done
