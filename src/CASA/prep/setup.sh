#!/bin/bash

# Fancy way to point MIDIR to two directories higher
# Should support symlinks, spaces, etc.
[[ -z "$MIROOT" ]] && MIROOT="$HOME/Projects/MiCASA"
DATADIR="data/v1/drivers"

YEAR0=2001					# First full year of retro product
YEARF=2023					# Last  full year of retro product

UPDATE0="2024-10-01"				# Start date for update
UPDATEF="2024-12-31"				# End   date for update

# HOSTS is a list of hosts to use for each year from $YEAR0 to $YEARF
# The last host is persisted if the list runs out

# You can use the below and comment out the NCCS Discover specific one below
# But beware, this will launch ~25 screen sessions on your current machine
#HOSTS=("$HOSTNAME")

# NCCS Discover hosts: discover11-14, 21-24 (not rn), 31-34
HOSTS=(\
    "discover11" "discover11" "discover11" "discover11" \
    "discover12" "discover12" "discover12" "discover12" \
    "discover13" "discover13" "discover13" "discover13" \
    "discover14" "discover14" "discover14" "discover14" \
    "discover31" "discover31" "discover31" "discover31" \
    "discover32" "discover32" "discover32" "discover32" \
    "discover33" "discover33" "discover33" "discover33" \
    "discover34" "discover34" "discover34" "discover34")

. ~/.bashrc
conda activate
