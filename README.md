# Más-Informada CASA (MiCASA)

This is obviously still quite rough. Check out the data README
[here](https://portal.nccs.nasa.gov/datashare/gmao/geos_carb/MiCASA/v1/MiCASA_README.pdf).

## Recipe

### Building inputs and Spinning up
Building inputs and spinning up is a complex process.
1. Use the `modvir` command to generate MODIS/VIIRS land cover, vegetation, and
burned area inputs.
2. Change into the `src/CASA` directory and use the `makeCASAinputAnnual.m` and
`makeCASAinputClim.m` commands to generate input. *More details coming.*
3. Run monthly CASA to spin up. Run the following in Matlab/Octave:
    ```
    runname = 'monthly-0.1deg';
    CASA;
    ```
4. Copy the monthly spin-up and restart data to the daily run. For example,
    ```
    cd ../..
    cp data-casa/monthly-0.1deg/native/spinUp_stage?.mat data-casa/daily-0.1deg/native
    cp data-casa/monthly-0.1deg/native/restart.mat data-casa/daily-0.1deg/native
    cd src/CASA
    ```

### Daily runs (with LoFI)
To run daily CASA, do:
```
runname = 'daily-0.1deg';
CASA;
convertOutput;
lofi.make_sink;
lofi.make_3hrly_land;
```
If desired, run the post-processing from the root directory:
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
