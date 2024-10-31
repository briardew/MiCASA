#!/bin/bash

echo "Only for checking final product. Beware running this for real ..."
exit 1

# discover11-14, 21-24
# discover22,24,31,32 are slow

# 2001-2003: discover11
for year in {2001..2003}; do
    ssh discover11 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done

# 2004-2007: discover12
for year in {2004..2007}; do
    ssh discover12 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done

# 2008-2011: discover13
for year in {2008..2011}; do
    ssh discover13 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done

# 2012-2015: discover14
for year in {2012..2015}; do
    ssh discover14 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done

# 2016-2019: discover21
for year in {2016..2019}; do
    ssh discover21 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done

# 2020-2022: discover23
for year in {2020..2022}; do
    ssh discover23 "
        cd /discover/nobackup/bweir/MiCASA
        mkdir -p logs/burn/${year}
        cd logs/burn/${year}
        screen -L -dmS modvir bash --login -c \"cd ../../..;modvir burn --mode regrid --beg $year-01-01 --end $year-12-31\"
        exit"
done
