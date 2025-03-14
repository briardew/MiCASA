#!/bin/bash

echo "Only for checking final product. Beware running this for real ..."
exit 1

# Fancy way to source setup and support symlinks, spaces, etc.
# At present only defines $MIDIR
. "$(dirname "$(readlink -f "$0")")"/setup.sh

# discover11-14, 21-24
# discover22,24,31,32 are slow

cd $MIDIR
mkdir -p logs/vegind/retro
cd logs/vegind/retro
screen -L -dmS modvir bash --login -c "cd $MIDIR;modvir vegind --data $DATADIR --mode fill --beg 2000-02-16"
