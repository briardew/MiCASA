#!/bin/bash

ssh discover-cssrw "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/vegind
    cd logs/mirror/vegind
    echo $hostname >> screenlog.0
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2024-08-01 --end 2024-09-30\"
    exit
"
ssh discover-cssrw "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/burn
    cd logs/mirror/burn
    echo $hostname >> screenlog.0
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode get --beg 2024-08-01 --end 2024-09-30\"
    exit
"
