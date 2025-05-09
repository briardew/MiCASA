#!/bin/bash

# Defaults, pretty hacky
MIROOT="$HOME/Projects/MiCASA"
VERSION="1"
RESTAG="x3600_y1800"
FEXT="nc4"

DATADIR="data/v$VERSION/drivers"

YEAR0=2001					# First full year of retro product
YEARF=2024					# Last  full year of retro product

UPDATE0="2025-01-01"				# Start date for update
UPDATEF="2025-01-31"				# End   date for update

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
