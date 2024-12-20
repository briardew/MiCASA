* Figure out how to automate land cover persistence for NRT

* Soil moisture bug

* Write NRT fire code in Python and set it to run
* File format for MODIS/VIIRS files?
    `MiCASA_v1_vegind_x3600_y1800_daily_20030803.nc4`
    `MiCASA_v1_burn_x3600_y1800_daily_20030803.nc4`
    `MiCASA_v1_cover_x3600_y1800_yearly_2003.nc4`
* Publish MODIS/VIIRS files on DataPortal so users don't need to reproduce them

* Proper cell weighted averages:
    `ds.weighted(weights).mean(('lat', 'lon'))`

* Provide global totals in metadata

Version 2
---
* Soil properties from SMAP nature run
* Fill with climatological daily change, not persistence

"Backlog"
---
* Move LoFI2 into MiCASA
* Clean up bin directory
* Go through and check FIXMEs

* Remove references to previous run in input maker: FUEL NEED
* Rewrite masker
* How to provide directory RC files to Python, Bash, Matlab, etc. code
  - Environment variables? They are environment specific after all
  - Python packages don't like to provide data
  - Version control?
* Pull code out of data-aux and utils directory
* General fix-ups for GitHub (repo name)

* FIRE!!!
* SOIL MOISTURE!!!
* Find other crop moisture and carbon concentration parameters (what does this
  even mean?): there is a lit review in the Wolf(e) and West paper's supplement
* Trist West crops?
* Check out 500m paper for MORT and FP, updated CC parameters
* Compare to Saatchi AGB; what does ED use/compare to?

Dumb thoughts
---
* We need to separate the trend and "baseline". Why not:
  - Compute early modern (say 2003-2008) and late modern (say 2017-2019)
    baselines from inversions

  - Kinda you want a balanced period and unbalanced. ENSO years will give you
    neutral sink but you don't want to tune to that.

  - Tune parameters to LPJ. Then use LPJ outside the MODIS/VIIRS period, i.e.,
    start-2001 and now-forecast. So CASA parameters would represent LPJ fPAR,
    soil, etc. -> flux. Ehhh ... not quite. Our "truths" are MODIS fPAR+BA and
    inversion NEE. Probably you'd want to tune LPJ and CASA parameters to the
    same NEE truth, then use LPJ outside the MODIS period.
