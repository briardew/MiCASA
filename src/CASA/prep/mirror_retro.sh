#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR="$(dirname "$(readlink -f "$0")")"
. "$PREPDIR"/setup.sh

# Give a chance to abort
echo "---"
echo "MODIS/VIIRS data mirror retro"
echo "---"
echo "WARNING: This will write files to $MIROOT/$DATADIR ..."
echo ""
read -n1 -s -r -p $"Press any key to continue ..." unused
echo ""

echo "ERROR: This is turned off by default to avoid any accidents ..."
echo "ERROR: Beware running this for real"
exit 1

# VI starts in the previous year (for fill)
year=$((YEAR0 - 1))
ssh "${HOSTS[0]}" "
    . "$PREPDIR"/setup.sh
    mkdir -p "$MIROOT"/logs/mirror/vegind-$year
    cd "$MIROOT"/logs/mirror/vegind-$year || exit
    screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode get --beg $year-01-01 --end $year-12-31\"
    exit"

NUMHOSTS=${#HOSTS[@]}
for year in $(seq -w $YEAR0 $YEARF); do
    nn=$((year - YEAR0 > NUMHOSTS - 1 ? NUMHOSTS - 1 : year - YEAR0))
    ssh "${HOSTS[$nn]}" "
        . "$PREPDIR"/setup.sh
        mkdir -p "$MIROOT"/logs/mirror/vegind-$year
        cd "$MIROOT"/logs/mirror/vegind-$year || exit
        screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode get --beg $year-01-01 --end $year-12-31\"
        exit"
    ssh "${HOSTS[$nn]}" "
        . "$PREPDIR"/setup.sh
        mkdir -p "$MIROOT"/logs/mirror/burn-$year
        cd "$MIROOT"/logs/mirror/burn-$year || exit
        screen -L -dmS modvir bash --login -c \"echo $hostname;modvir burn --data "$MIROOT/$DATADIR" --mode get --beg $year-01-01 --end $year-12-31\"
        exit"
done
