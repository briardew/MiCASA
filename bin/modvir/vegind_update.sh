#!/bin/bash

cd /discover/nobackup/bweir/MiCASA
mkdir -p logs/vegind/update
cd logs/vegind/update
screen -L -dmS modvir bash --login -c "cd ../../..;modvir vegind --mode fill --beg 2023-12-31"
