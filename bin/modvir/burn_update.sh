#!/bin/bash

# discover11-14, 21-24
# discover22,24,31,32 are slow

# 2024
ssh discover21 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/burn/2024
    cd logs/burn/2024
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg 2024-08-01 --end 2024-09-30\"
    exit"
