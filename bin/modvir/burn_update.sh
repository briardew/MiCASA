#!/bin/bash

# discover11-14, 21-24
# discover22,24,31,32 are slow

# 2024: discover21
for year in {2024..2024}; do
    ssh discover21 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done
