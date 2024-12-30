# Más-Informada CASA (MiCASA)

This is obviously still quite rough. Check out the data README
[here](https://portal.nccs.nasa.gov/datashare/gmao/geos_carb/MiCASA/v1/MiCASA_README.pdf).

## Recipe
This is still very rough. Working on it.
1. If starting from a fresh run, you'll need to generate the inputs. This is a
complex process with more details coming.
2. Run CASA. Go to `src/CASA`. If spinning up for the first time, run the
following in Matlab/Octave:
    ```
    runname = 'monthly-0.1deg';
    CASA;
    ```
3. If running daily, copy the spin-up and restart data from the montly run. For
example,
    ```
    cd ../..
    cp data-casa/monthly-0.1deg/native/spinUp_stage?.mat data-casa/daily-0.1deg/native
    cp data-casa/monthly-0.1deg/native/restart.mat data-casa/daily-0.1deg/native
    cd src/CASA
    ```
Then run daily CASA:
    ```
    runname = 'daily-0.1deg';
    CASA;
    convertOutput;
    lofi.make_sink;
    lofi.make_3hrly_land;
    ```
4. Run the post-processing from the root directory:
    ```
    cd ../..
    ./bin/post/process.sh
    ```

## Maintaining local configurations
MiCASA configuration is still pretty rough, but I've made a lot of progress.
The main configuration files are `src/CASA/defineConstants.m` and
`bin/post/setup.sh`. The former defines the CASA model settings along with
input and output directories and the latter post processes. It is not necessary
to run this for personal installs.

You may make changes to these configuration files that you won't want a `git
pull` to overwrite. In such a case, try
```
git stash
git pull
git stash pop
```
