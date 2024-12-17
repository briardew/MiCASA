This is a collection of utilities for generating MODIS/VIIRS refeclatance data.
Generating the entire, 20+ year record takes a long time. They are written
specifically for NCSS/Discover and using its CSS network-attached storage.
They may be useful to the general audience or generalizable, but right now I'm
happy enough that it doesn't reference my nobackup.

Notes:
- By default, these utilities place everything in directories two levels
  higher. This can be changed in `setup.sh`.
- It's good practice to mirror before you generate products as this takes quite
  a bit of time and can fail. This is why the mirroring is separated.
