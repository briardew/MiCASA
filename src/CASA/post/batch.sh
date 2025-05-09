#!/bin/bash

# This is a big script for batch reprocessing a retrospective stream.  It is
# very NCCS Discover specific.  Not much effort has been put into
# modularization because it's likely this will depend heavily on the computing
# platform and hopefully only run a handful of times.

echo "Only for checking final product. Beware running this for real ..."
exit 1

# Still really not great
VERSION="1"
COMMAND="$1.sh --ver $VERSION"

# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR"/setup.sh

if [[ "$#" -lt 1 || ! -f "$COMMAND" ]]; then
    echo "ERROR: Please provide a valid command to run in batch. For example,"
    echo "    $(basename "$0") process"
    echo ""
    echo "Valid commands are: process, cog, upload"
    exit 1
fi

# 2001-2009: discover21
for year in {2001..2009}; do
    NODE="discover21"
    [[ "$1" == "upload" ]] && NODE="discover31"				# Hack for upload
    ssh "$NODE" "
        cd $MIROOT
        mkdir -p logs/post/$year
        cd logs/post/$year
        screen -L -dmS post bash --login -c \"cd $MIROOT;$POSTDIR/$COMMAND $year --batch\"
        exit"
done

# 2010-2018: discover22
for year in {2010..2018}; do
    NODE="discover22"
    [[ "$1" == "upload" ]] && NODE="discover32"				# Hack for upload
    ssh "$NODE" "
        cd $MIROOT
        mkdir -p logs/post/$year
        cd logs/post/$year
        screen -L -dmS post bash --login -c \"cd $MIROOT;$POSTDIR/$COMMAND $year --batch\"
        exit"
done

# 2019-2023: discover23
for year in {2019..2023}; do
    NODE="discover23"
    [[ "$1" == "upload" ]] && NODE="discover33"				# Hack for upload
    ssh "$NODE" "
        cd $MIROOT
        mkdir -p logs/post/$year
        cd logs/post/$year
        screen -L -dmS post bash --login -c \"cd $MIROOT;$POSTDIR/$COMMAND $year --batch\"
        exit"
done
