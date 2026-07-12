This is a collection of utilities for generating MODIS/VIIRS refeclatance data.
Generating the entire, 25+ year record takes a long time. They are written
specifically for NCSS Discover and using its CSS network-attached storage.
They may be useful to the general audience or generalizable, but right now I'm
happy enough that it doesn't reference my nobackup.

Notes:
- By default, these utilities place everything in `$HOME/Projects/MiCASA`.
  This can be changed in `setup.sh`.
- It's good practice to mirror before you generate products as this takes quite
  a bit of time and can fail. This is why the mirroring is separated.

This is a set of utilities for publishing the output of MiCASA. They are kept
here as an example, but they have some aspects that are specific to NCCS
Discover and the specific run (viz., resolution). I'm trying my best to make
them modular and adaptable. Long-term they will probably be transitioned to
Python.
