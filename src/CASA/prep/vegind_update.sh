#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR="$(dirname "$(readlink -f "$0")")"
. "$PREPDIR"/setup.sh

# Give a chance to abort
echo "---"
echo "MODIS/VIIRS vegetation fill update"
echo "---"
echo "WARNING: This will write files to $MIROOT/$DATADIR ..."
echo ""
read -n1 -s -r -p $"Press any key to continue ..." unused
echo ""

# Fill needs to start a day early
UPDATEB4=$(date -d "$UPDATE0-1 days" +%F)
ssh "${HOSTS[0]}" "
    . "$PREPDIR"/setup.sh
    mkdir -p "$MIROOT"/logs/vegind/update
    cd "$MIROOT"/logs/vegpre/update || exit
    screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode fill --beg $UPDATEB4 --end $UPDATEF\"
    exit"
