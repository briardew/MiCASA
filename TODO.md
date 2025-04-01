This initial software release will focus on two use cases: 1. Production of
public MiCASA data, and 2. Derivative experiments by users with different
constants, assumptions, etc. The latter will be well enabled by housing MiCASA
driver data on a public share point for both NCSS Discover users and on the
NCCS DataPortal for outside users. The actual MiCASA outputs are also available
through GES DISC while the driver data is not.

* Have `restart.mat` saved at the very end? No need for `do_restart_all`?

* Compress, and stage on NCCS DataPortal (in a dir named `drivers`?). Don't
  concatenate into a single file (drastic time differences/applications).

* Clean up `bin` directory
* Clean up `masinfo` directory
* Improve post-processing

* Have everything reference a global configuration file. Right now the code
  and data have to sit in the same root directory. This is because the
  config is spread over Python, Matlab, and Bash scripts. I've done a lot
  to make the config consistent, but this has relied upon fancy tricks,
  not simplicity and directness.

"Backlog"
---
* Go through and check FIXMEs

* Remove references to previous run in input maker: FUEL NEED
* Rewrite masker
* Pull code out of data-aux and utils directory
* General fix-ups for GitHub (repo name)

* Find other crop moisture and carbon concentration parameters (what does this
  even mean?): there is a lit review in the Wolf(e) and West paper's supplement
* Trist West crops?
* Check out 500m paper for MORT and FP, updated CC parameters
* Compare to Saatchi AGB; what does ED use/compare to?

Version 2
---
* Provide global totals in metadata
* Proper cell weighted averages:
    `ds.weighted(weights).mean(('lat', 'lon'))`
* Move to IT met for retrospective
* Soil moisture revamp to use SMAP/nature run
* Fill inputs with climatological daily change, not persistence

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
