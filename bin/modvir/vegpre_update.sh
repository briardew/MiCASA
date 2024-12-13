#!/bin/bash

# discover11-14, 21-24
# discover22,24,31,32 are slow

MIDIR="/discover/nobackup/bweir/MiCASA"

ssh discover-cssrw "
    cd $MIDIR
    mkdir -p logs/vegpre/2024b
    cd logs/vegpre/2024b
    echo $hostname >> screenlog.0
    screen -L -dmS modvir bash --login -c \"cd $MIDIR;modvir vegind --mode regrid --beg 2024-08-01 --end 2024-09-30\"
    exit"
