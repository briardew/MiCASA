# Más-Informada CASA (MiCASA)

This is obviously still quite rough. Check out the data README
[here](https://portal.nccs.nasa.gov/datashare/gmao/geos_carb/MiCASA/v1/MiCASA_README.pdf).

## Recipe (so far, ugh)
1. Go to `src/CASA` and run the following in Matlab/Octave:
    1. `CASA`
    2. `convertOuput`
    3. `lofi.make_sink`
    4. `lofi.make_3hrly_land`
2. Go back to root and run `./bin/post.sh process`

## Yucky stuff
It's still pretty hard to maintain a local configuration that doesn't get
overwritten by running `git pull`. So far, I can suggest running
```
git update-index --skip-worktree bin/post/setup.sh
```
This can be turned off by running
```
git update-index --no-skip-worktree bin/post/setup.sh
```
I still need a better solution as that `setup.sh` should be able to support
multiple different runs.
