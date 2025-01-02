# Más-Informada CASA (MiCASA)

This is obviously still quite rough. Check out the data README
[here](https://portal.nccs.nasa.gov/datashare/gmao/geos_carb/MiCASA/v1/MiCASA_README.pdf).

## Recipe
Most of the work involved in getting a run going revolves around building inputs and
spinning up, as described in the following two subsections. Once this is done, daily
runs and side experiments are fairly straightforward, as described in the final
subsection.

### Building MODIS/VIIRS inputs
1. Install the MiCASA Python package in editable mode following the instructions in
`requirements.txt`.
2. Run `modvir --help` to get an example of how to generate the MODIS/VIIRS files.
3. Look at the utilities in `bin/modvir` to get an idea of how to generate and update
MODIS/VIIRS inputs.

*NOTE*: MiCASA was originally designed to run on NASA high-performance
computing assets. Mirroring the entire `MCD12Q1`, `MOD44B`, `MCD43A4`, and
`MCD64A1` collections takes a lot of time and space, especially the `MCD43A4`
collection. The next version of MiCASA will support running on individual
MODIS/VIIRS tiles and using services like OPeNDAP to make this process easier.
We also plan to archive the inputs we use so that the user need not reproduce
this step. Nevertheless, these files will be about 4GB per year, so about 100GB
total for the entire 24+ year record.

### Spinning up
1. Build the climatological and annual inputs needed for spin-up. Change into
the `src/CASA` directory and run the following in Matlab/Octave:
    ```
    runname = 'monthly-0.1deg';
    makeCASAinputClim;
    makeCASAinputAnnual;
    ```
2. Run monthly CASA to spin up. Run the following in Matlab/Octave:
    ```
    runname = 'monthly-0.1deg';
    CASA;
    ```
3. Copy the monthly spin-up and restart data to the daily run. For example,
    ```
    cd ../..
    cp data-casa/monthly-0.1deg/native/spinUp_stage?.mat data-casa/daily-0.1deg/native
    cp data-casa/monthly-0.1deg/native/restart.mat data-casa/daily-0.1deg/native
    cd src/CASA
    ```

### Daily runs (with LoFI)
Once inputs are built and the monthly spin-up is done, you can run daily CASA in
Matlab/Octave by doing the following:
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

This will end once the MODIS/VIIRS input end. To continue, simply update the
MODIS/VIIRS inputs using the `modvir` command as above. The remaining inputs do
not need to be updated: they are either climatological or specifically for the
monthly spin-up.

## Maintaining local configurations
MiCASA configuration is still pretty rough, but I've made a lot of progress.
The main configuration files are `src/CASA/defineConstants.m` and
`bin/post/setup.sh`. The former defines the CASA model settings along with
input and output directories and the latter post processes. It is not necessary
to run the post processing for personal installs.

You may make changes to these configuration files that you won't want a `git
pull` to overwrite. In such a case, try
```
git stash
git pull
git stash pop
```
