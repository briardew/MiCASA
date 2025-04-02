#!/bin/bash

# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR="$(dirname "$(readlink -f "$0")")"
. "$PREPDIR"/setup.sh

# Give a chance to abort
echo "---"
echo "MODIS/VIIRS vegetation regrid retro"
echo "---"
echo "WARNING: This will write files to $MIROOT/$DATADIR ..."
echo ""
read -n1 -s -r -p $"Press any key to continue ..." unused
echo ""

# VI starts in the previous year (for fill)
YEAR0VEG=$((YEAR0 - 1))

NUMHOSTS=${#HOSTS[@]}
for year in $(seq -w $YEAR0VEG $YEARF); do
    nn=$((year - YEAR0VEG > NUMHOSTS - 1 ? NUMHOSTS - 1 : year - YEAR0VEG))
    ssh "${HOSTS[$nn]}" "
        . "$PREPDIR"/setup.sh
        mkdir -p "$MIROOT"/logs/vegpre/${year}a
        cd "$MIROOT"/logs/vegpre/${year}a || exit
        screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode regrid --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh "${HOSTS[$nn]}" "
        . "$PREPDIR"/setup.sh
        mkdir -p "$MIROOT"/logs/vegpre/${year}b
        cd "$MIROOT"/logs/vegpre/${year}b || exit
        screen -L -dmS modvir bash --login -c \"echo $hostname;modvir vegind --data "$MIROOT/$DATADIR" --mode regrid --beg $year-07-01 --end $year-12-31\"
        exit"
done
