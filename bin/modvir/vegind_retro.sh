#!/bin/bash

echo "Only for checking final product. Beware running this for real ..."
exit 1

# discover11-14, 21-24
# discover22,24,31,32 are slow

cd /discover/nobackup/bweir/MiCASA
mkdir -p logs/vegind/retro
cd logs/vegind/retro
screen -L -dmS modvir bash --login -c "cd ../../..;modvir vegind --mode fill --beg 2000-02-16"
