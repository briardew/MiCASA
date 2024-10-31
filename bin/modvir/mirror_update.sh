#!/bin/bash

# 2024-onwards: CSS space & discover21
ssh discover21 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/vegind
    cd logs/mirror/vegind
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2024-01-01 --end 2024-07-31\"
    exit
"
ssh discover21 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/burn
    cd logs/mirror/burn
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode get --beg 2024-01-01 --end 2024-07-31\"
    exit
"
