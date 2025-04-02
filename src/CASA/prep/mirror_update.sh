#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR="$(dirname "$(readlink -f "$0")")"
. "$PREPDIR"/setup.sh

# Give a chance to abort
echo "---"
echo "MODIS/VIIRS data mirror update"
echo "---"
echo "WARNING: This will write files to $MIROOT/$DATADIR ..."
echo ""
read -n1 -s -r -p $"Press any key to continue ..." unused
echo ""

year=$((YEARF + 1))
ssh "${HOSTS[-1]}" "
    . "$PREPDIR"/setup.sh
    mkdir -p "$MIROOT"/logs/mirror/burn-$year
    cd "$MIROOT"/logs/mirror/burn-$year
    screen -L -dmS modvir bash --login -c \"echo $hostname;modvir burn --data "$MIROOT/$DATADIR" --mode get --beg $UPDATE0 --end $UPDATEF\"
    exit"
ssh "${HOSTS[-1]}" "
    . "$PREPDIR"/setup.sh
    mkdir -p "$MIROOT"/logs/mirror/vegind-$year
    cd "$MIROOT"/logs/mirror/vegind-$year
    screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode get --beg $UPDATE0 --end $UPDATEF\"
    exit"
