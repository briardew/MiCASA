#!/bin/bash

#echo "Only for checking final product. Beware running this for real ..."
#exit 1

# Still really not great
MIDIR="$(dirname "$(readlink -f "$0")")"
COMMAND="post/$1.sh"

if [[ "$#" -lt 1 || ! -f "$COMMAND" ]]; then
    echo "ERROR: Please provide a valid command to run in batch. For example," 1>&2
    echo "    $0 process" 1>&2
    echo ""
    echo "Valid commands are: process, cog, upload" 1>&2
    exit 1
fi

# 2001-2009: discover21
for year in {2001..2009}; do
    NODE="discover21"
    [[ "$1" == "upload" ]] && NODE="discover31"				# Hack for upload
    ssh "$NODE" "
        cd $MIDIR
        mkdir -p ../logs/post/$year
        cd ../logs/post/$year
        screen -L -dmS post bash --login -c \"cd $MIDIR/..;$MIDIR/$COMMAND $year batch\"
        exit"
done

# 2010-2018: discover22
for year in {2010..2018}; do
    NODE="discover22"
    [[ "$1" == "upload" ]] && NODE="discover32"				# Hack for upload
    ssh "$NODE" "
        cd $MIDIR
        mkdir -p ../logs/post/$year
        cd ../logs/post/$year
        screen -L -dmS post bash --login -c \"cd $MIDIR/..;$MIDIR/$COMMAND $year batch\"
        exit"
done

# 2019-2023: discover23
for year in {2019..2023}; do
    NODE="discover23"
    [[ "$1" == "upload" ]] && NODE="discover33"				# Hack for upload
    ssh "$NODE" "
        cd $MIDIR
        mkdir -p ../logs/post/$year
        cd ../logs/post/$year
        screen -L -dmS post bash --login -c \"cd $MIDIR/..;$MIDIR/$COMMAND $year batch\"
        exit"
done
