#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR="$(dirname "$(readlink -f "$0")")"
. "$PREPDIR"/setup.sh

# Give a chance to abort
echo "---"
echo "MODIS/VIIRS vegetation regrid update"
echo "---"
echo "WARNING: This will write files to $MIROOT/$DATADIR ..."
echo ""
read -n1 -s -r -p $"Press any key to continue ..." unused
echo ""

year=$((YEARF + 1))
ssh "${HOSTS[-1]}" "
    . "$PREPDIR"/setup.sh
    mkdir -p "$MIROOT"/logs/vegpre/$year
    cd "$MIROOT"/logs/vegpre/$year || exit
    screen -L -dmS modvir bash --login -c \"echo $HOSTNAME;modvir vegind --data "$MIROOT/$DATADIR" --mode regrid --beg $UPDATE0 --end $UPDATEF\"
    exit"
