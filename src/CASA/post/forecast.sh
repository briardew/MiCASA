#!/bin/bash

# Brutal hack to persist for a specified number of days. Hope is to actually do
# something scientifically defensible. Expect this script and its use to be
# volatile.

echo "---"
echo "MiCASA forecasting" 
echo "---"

# Fancy way to source setup and support symlinks, spaces, etc.
. "$(dirname "$(readlink -f "$0")")"/setup.sh

if [[ "$NFCST" -le 0 || 1000 -le "$NFCST" ]]; then
    echo "WARNING: Using the default forecast number of days"
    NFCST=7
fi

# Simple outputs, warnings, and errors
# Would be nice to have a help file (***FIXME***)
echo "WARNING: This script overwrites files no matter what" 1>&2

echo "Output directory: $DIROUT"
echo "Collection: $COLTAG"

# Get and check start date and forecast length
daybeg=$(date -d "$1" +%F)
if [[ -z "$daybeg" ]]; then
    echo "ERROR: Please provide a valid start date. For example," 1>&2
    echo "    $0 $(date -d '-1 days' +%F)" 1>&2
    exit 1
fi
echo "Start date: $daybeg"
echo "Num days:   $NFCST"

# Give a chance to abort
if [[ "$2" != "--batch" ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

# Run
# ---
daynow="$daybeg"
year=$(date -d "$daynow" +%Y)
mon=$(date -d "$daynow" +%m)
day=$(date -d "$daynow" +%d)

ff="${COLTAG}_3hrly_$year$mon$day.$FEXT"
f3hr="$DIROUT/3hrly/$year/$mon/$ff"
# Exit if 3hrly file is missing
if [[ ! -f "$f3hr" ]]; then
    echo "ERROR: 3-hourly file for $daybeg is missing"
    echo "$f3hr"
    exit 1
fi

ff="${COLTAG}_daily_$year$mon$day.$FEXT"
fday="$DIROUT/daily/$year/$mon/$ff"
# Exit if daily file is missing
if [[ ! -f "$fday" ]]; then
    echo "ERROR: Daily file for $daybeg is missing"
    echo "$fday"
    exit 1
fi

for num in $(seq 1 "$NFCST"); do
    daynow=$(date -d "$daybeg +$num days" +%F)
    year=$(date -d "$daynow" +%Y)
    mon=$(date -d "$daynow" +%m)
    day=$(date -d "$daynow" +%d)

    ff="${COLTAG}_3hrly_$year$mon$day.$FEXT"
    mkdir -p "$DIROUT/3hrly/$year/$mon"
    fout="$DIROUT/3hrly/$year/$mon/$ff"
    echo "Writing $fout ..."
    ncap2 -O -s "time=time+$num;time_bnds=time_bnds+$num" "$f3hr" "$fout"

    ff="${COLTAG}_daily_$year$mon$day.$FEXT"
    mkdir -p "$DIROUT/daily/$year/$mon"
    fout="$DIROUT/daily/$year/$mon/$ff"
    echo "Writing $fout ..."
    ncap2 -O -s "time=time+$num;time_bnds=time_bnds+$num" "$fday" "$fout"
done
