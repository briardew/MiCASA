#!/bin/bash

# discover11-14, 21-24
# discover22,24,31,32 are slow

# Fancy way to source setup and support symlinks, spaces, etc.
# At present only defines $MIDIR
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# 2024
ssh discover21 "
    cd $MIDIR
    mkdir -p logs/burn/2024
    cd logs/burn/2024
    screen -L -dmS modvir bash --login -c \"cd $MIDIR;modvir burn --data $DATADIR --mode regrid --beg 2024-08-01 --end 2024-09-30\"
    exit"
