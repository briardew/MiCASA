#!/bin/bash

# Documented by Gumbricht et al. (2017; https://doi.org/10.1111/gcb.13689)
# Data available from https://doi.org/10.17528/CIFOR/DATA.00058 as a 7zip file?!
# Also goes through a link, so can't automatically download and transform
# Data provided under a Creative Commons Attribution 4.0 International license
# @data{CIFOR/DATA.00058_2017,
# author = {Gumbricht, T. and Román-Cuesta, R.M. and Verchot, L.V. and Herold, M. and Wittmann, F and Householder, E. and Herold, N. and Murdiyarso, D.},
# publisher = {Center for International Forestry Research (CIFOR)},
# title = {{Tropical and Subtropical Wetlands Distribution}},
# UNF = {UNF:6:Bc9aFtBpam27aFOCMgW71Q==},
# year = {2017},
# version = {V7},
# doi = {10.17528/CIFOR/DATA.00058},
# url = {https://doi.org/10.17528/CIFOR/DATA.00058}
# }

fin='TROP-SUBTROP_PeatV21_2016_CIFOR.tif'
fout1='TROP-SUBTROP_PeatV21_2016_CIFOR.x1800_y3600.tif'
fout5='TROP-SUBTROP_PeatV21_2016_CIFOR.x360_y720.tif'

gdalwarp -t_srs EPSG:4326 -te -180 -90 180 90 -tr 0.1 0.1 -ot float32 -r average -dstnodata 0 $fin $fout1
gdalwarp -t_srs EPSG:4326 -te -180 -90 180 90 -tr 0.5 0.5 -ot float32 -r average -dstnodata 0 $fin $fout5
