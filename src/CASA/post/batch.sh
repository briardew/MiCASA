#!/usr/bin/env bash

# This is a big script for batch processing a retrospective stream.  It is
# very NCCS Discover specific.  Not much effort has been put into
# modularization because it's likely this will depend heavily on the computing
# platform and hopefully only run a handful of times.

# Shellcheck will complain about $ROOTIN not being escaped below. This is the
# behavior we want as $ROOTIN is defined on the client side but undefined on
# the server side. Same goes for $POSTDIR and $year.

# Still really not great
VERSION="1"
COMMAND="$1.sh --ver $VERSION"

echo "WARNING: This generates THE ENTIRE v$VERSION PRODUCT."
echo "Beware running this for real ..."
echo ""
exit 1

# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR"/setup.sh

if [[ "$#" -lt 1 || ! -f "$COMMAND" ]]; then
    echo "ERROR: Please provide a valid command to run in batch. For example,"
    echo "    $(basename "$0") process"
    echo ""
    echo "Valid commands are: check, cogmake, cogupload, drivers, process"
    exit 1
fi

# 2001-2009: discover31
for year in {2001..2009}; do
    NODE="discover31"
    ssh "$NODE" "
        cd $ROOTIN
        mkdir -p logs/post/$year
        cd logs/post/$year
        screen -L -dmS post bash --login -c \"cd $ROOTIN;$POSTDIR/$COMMAND $year --batch\"
        exit"
done

# 2010-2019: discover32
for year in {2010..2019}; do
    NODE="discover32"
    ssh "$NODE" "
        cd $ROOTIN
        mkdir -p logs/post/$year
        cd logs/post/$year
        screen -L -dmS post bash --login -c \"cd $ROOTIN;$POSTDIR/$COMMAND $year --batch\"
        exit"
done

# 2020-2026: discover33
for year in {2020..2026}; do
    NODE="discover33"
    ssh "$NODE" "
        cd $ROOTIN
        mkdir -p logs/post/$year
        cd logs/post/$year
        screen -L -dmS post bash --login -c \"cd $ROOTIN;$POSTDIR/$COMMAND $year --batch\"
        exit"
done
