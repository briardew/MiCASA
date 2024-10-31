#!/bin/bash

echo "Only for checking final product. Beware running this for real ..."
exit 1

# 2000-2004: CSS space & discover21
ssh discover21 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/2000
    cd logs/mirror/2000
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2000-01-01 --end 2004-12-31\"
    exit
"
sleep 30

# 2005-2009: CSS space & discover22
ssh discover22 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/2005
    cd logs/mirror/2005
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2005-01-01 --end 2009-12-31\"
    exit
"
sleep 30

# 2010-2014: CSS space & discover23
ssh discover23 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/2010
    cd logs/mirror/2010
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2010-01-01 --end 2014-12-31\"
    exit
"
sleep 30

# 2015-2019: CSS space & discover06
ssh discover06 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/2015
    cd logs/mirror/2015
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2015-01-01 --end 2019-12-31\"
    exit
"
sleep 30

# 2020-onwards: CSS space & discover07
ssh discover07 "
    cd /discover/nobackup/bweir/MiCASA
    mkdir -p logs/mirror/2020
    cd logs/mirror/2020
    screen -L -dmS modvir bash --login -c \"cd ../../..;modvir vegind --mode get --beg 2020-01-01\"
    exit
"
sleep 30
