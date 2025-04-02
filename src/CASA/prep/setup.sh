#!/bin/bash

# Fancy way to point MIDIR to two directories higher
# Should support symlinks, spaces, etc.
[[ -z "$MIROOT" ]] && MIROOT="$HOME/Projects/MiCASA"
DATADIR="data/v1/drivers"

YEAR0=2001					# First full year of retro product
YEARF=2023					# Last  full year of retro product

UPDATE0="$year-10-01"				# Start date for update
UPDATEF="$year-12-31"				# End   date for update

# HOSTS is a list of hosts to use for each year from $YEAR0 to $YEARF
# The last host is persisted if the list runs out

# You can use the below and comment out the NCCS Discover specific one below
# But beware, this will launch ~25 screen sessions on your current machine
#HOSTS=("$hostname")

# NCCS Discover hosts: discover11-14, 21-24, 31-34
# discover22,24,31,32 appear slow?
HOSTS=(\
    "discover11" "discover11" "discover11" "discover11" \
    "discover12" "discover12" "discover12" "discover12" \
    "discover13" "discover13" "discover13" "discover13" \
    "discover14" "discover14" "discover14" "discover14" \
    "discover21" "discover21" "discover21" "discover21" \
    "discover23" "discover23" "discover23" "discover23")

. ~/.bashrc
conda activate
