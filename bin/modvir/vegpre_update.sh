#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
# At present only defines $MIDIR
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# discover11-14, 21-24
# discover22,24,31,32 are slow

ssh discover-cssrw "
    . ~/.bashrc
    conda activate
    cd $MIDIR
    mkdir -p logs/vegpre/2024b
    cd logs/vegpre/2024b
    echo $hostname >> screenlog.0
    screen -L -dmS modvir bash --login -c \"cd $MIDIR;modvir vegind --data $DATADIR --mode regrid --beg 2024-10-01 --end 2024-12-31\"
    exit"
