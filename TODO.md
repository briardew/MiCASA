* Remember to set `OMP_NUM_THREADS` if you ever want this to finish

* RUN THE DAMN THING!!!
  - Finish daily vegetation index
  - Finish daily burned area
  - Add met regridding to CASA code. Data loader should read met file if it
    exists, regrids otherwise, and saves if requested
  - Other fields?
  - Add option to run daily. Can nmonths vary by year? Leap days?
  - Will need to remove time-dependence of arrays; save will be done every
    day; not sure about spin-up, read may have to be done every day

* Make it nice:
  - Indicate what land cover was used in vegpre and burn files
  - Overall land cover improvements, much is hard-coded
  - Tune parameters so GIMMS NDVI looks like fPAR we have in CASA
  - Revisit censoring water cells towards 0 instead of NDVIMIN
  - Get our NDVI to look as much like GIMMS as possible
  - Polish filler:
    * Make high-latitude persistence look as much like GIMMS as possible

Dumb thoughts:
We really need to separate the trend and "baseline". Why not:
1. Compute early modern (say 2003-2008) and late modern (say 2017-2019)
baselines from inversions

Kinda you want a balanced period and unbalanced. ENSO years will give you
neutral sink but you don't want to tune to that.

* Tune parameters to LPJ. Then use LPJ outside the MODIS/VIIRS period, i.e.,
start-2001 and now-forecast. So CASA parameters would represent
LPJ fPAR, soil, etc. -> flux. Ehhh ... not quite. Our "truths" are MODIS
fPAR+BA and inversion NEE. Probably you'd want to tune LPJ and CASA
parameters to the same NEE truth, then use LPJ outside the MODIS period.
