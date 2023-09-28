#!/bin/bash

#echo "Only for checking final product. Beware running this for real ..."
#exit 1

# discover06-07, 11, 21-24

# 2000-2003: discover06
for year in {2000..2003}
do
    ssh discover06 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover06 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2004-2006: discover07
for year in {2004..2006}
do
    ssh discover07 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover07 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2007-2009: discover12
for year in {2007..2009}
do
    ssh discover12 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover12 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2010-2012: discover13
for year in {2010..2012}
do
    ssh discover13 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover13 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2013-2015: discover14
for year in {2013..2015}
do
    ssh discover14 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover14 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2016-2018: discover21
for year in {2016..2018}
do
    ssh discover21 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover21 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2019-2021: discover22
for year in {2019..2021}
do
    ssh discover22 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover22 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2022-2024: discover23
for year in {2022..2024}
do
    ssh discover23 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover23 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done

# 2025-2027: discover24
for year in {2025..2027}
do
    ssh discover24 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}
        cd logs/prep${year}
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-01-01 --end $year-06-30\"
        exit"
    ssh discover24 "
        cd /discover/nobackup/bweir/miCASA
        mkdir -p logs/prep${year}b
        cd logs/prep${year}b
        screen -L -dmS modvir bash --login -c \"cd ..;cd ..;modvir vegind --mode prep --beg $year-07-01 --end $year-12-31\"
        exit"
done
