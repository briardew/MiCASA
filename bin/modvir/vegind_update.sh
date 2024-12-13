#!/bin/bash

MIDIR="/discover/nobackup/bweir/MiCASA"

cd "$MIDIR" || exit
mkdir -p logs/vegind/update
cd logs/vegind/update
screen -L -dmS modvir bash --login -c "cd $MIDIR;modvir vegind --mode fill --beg 2024-07-31 --end 2024-09-30"
