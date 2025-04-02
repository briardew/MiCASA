#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR="$(dirname "$(readlink -f "$0")")"
. "$PREPDIR"/setup.sh

# Give a chance to abort
echo "---"
echo "MODIS/VIIRS vegetation fill retro"
echo "---"
echo "WARNING: This will write files to $MIROOT/$DATADIR ..."
echo ""
read -n1 -s -r -p $"Press any key to continue ..." unused
echo ""

ssh "${HOSTS[0]}" "
    . "$PREPDIR"/setup.sh
    mkdir -p "$MIROOT"/logs/vegind/retro
    cd "$MIROOT"/logs/vegpre/retro || exit
    screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode fill --beg 2000-02-16\"
    exit"
