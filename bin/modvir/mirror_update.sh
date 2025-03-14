#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
# At present only defines $MIDIR
. "$(dirname "$(readlink -f "$0")")"/setup.sh

ssh discover-cssrw "
    cd $MIDIR
    mkdir -p logs/mirror/vegind
    cd logs/mirror/vegind
    echo $hostname >> screenlog.0
    screen -L -dmS modvir bash --login -c \"cd $MIDIR;modvir vegind --data $DATADIR --mode get --beg 2024-10-01 --end 2024-12-31\"
    exit
"
ssh discover-cssrw "
    cd $MIDIR
    mkdir -p logs/mirror/burn
    cd logs/mirror/burn
    echo $hostname >> screenlog.0
    screen -L -dmS modvir bash --login -c \"cd $MIDIR;modvir burn --data $DATADIR --mode get --beg 2024-10-01 --end 2024-12-31\"
    exit
"
