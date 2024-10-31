# NOTE: This utility is in development and doesn't work yet

import numpy as np
import xarray as xr

from os import path
from subprocess import check_call
from datetime import datetime, timedelta
from time import time
from scipy.io import loadmat

# Should get these from input (trivially parallel)
YEAR0 = 2001
YEARF = 2023

#defineConstants;
# Variables needed from above
DIRCASA = '/discover/nobackup/bweir/MiCASA/data-casa'
runname = 'daily-0.1deg'
NLON = 3600
NLAT = 1800
DODAILY = True

HEADIN  = path.join(DIRCASA, runname, 'native')
HEADOUT = path.join(DIRCASA, runname, 'output')
VERSTR  = 'v1'

# Add herbivory to respiration? and variable name
ADDHER = True
VARHER = 'HER'
if ADDHER: print('Adding herbivory to respiration ...')

# Structure defining what to process (monthly replaced by daily below)
# EET defined in Field et al. (1995; https://doi.org/10.1016/0034-4257(94)00066-V)
fluxes = [
    {'orig':'NPP',  'name':'NPP',  'desc':'Net primary productivity',  'units':'g C m-2 day-1'},
    {'orig':'RES',  'name':'Rh',   'desc':'Heterotrophic respiration', 'units':'g C m-2 day-1'},
    {'orig':'FIRE', 'name':'FIRE', 'desc':'Fire emission',      'units':'g C m-2 month-1'},
    {'orig':'FUE',  'name':'FUEL', 'desc':'Fuel wood emission', 'units':'g C m-2 month-1'},
]
extras = [
    {'orig':'HER',      'name':'HER',      'desc':'Herbivory emission', 'units':'g C m-2 day-1'},
    {'orig':'EET',      'name':'ET',       'desc':'Evapotranspiration', 'units':'mm day-1'},
    {'orig':'soilm',    'name':'SOILM',    'desc':'Soil moisture',      'units':'mm'},
    {'orig':'NPPtemp',  'name':'NPPtemp',  'desc':'NPP temperature constraint', 'units':'g C m-2 day-1'},
    {'orig':'NPPmoist', 'name':'NPPmoist', 'desc':'NPP moisture constraint',    'units':'g C m-2 day-1'},
]
datasets = fluxes + extras

# Initialize
# ===
restag = 'x' + str(NLON) + '_y' + str(NLAT)

# For extracting variables
mask = loadmat(path.join(HEADIN, 'spinUp_stage1.mat'),
    variable_names=('mask'))['mask']

# For debugging: test should vary as latitude in 2D
test = np.nan + np.zeros_like(mask)
latin = loadmat(path.join(HEADIN, 'spinUp_stage1.mat'), 
    variable_names=('latitude'))['latitude']
test.flat[mask.flat == 1] = latin
# Above should give correct shape, now flip to start from South
test = np.flipud(test)

def loadcasa(dataset, dirin):
    '''Load native CASA data'''
    vin   = dataset['orig']
    vout  = dataset['name']
    units = dataset['units']

    if vin.upper() == 'FIRE':
        vherb = 'COMherb'
        vwood = 'COMwood'
        vdefo = 'COMdefo'
        vpeat = 'COMpeat'
        datain = (
              loadmat(path.join(dirin, vherb+'.mat'))[vherb]
            + loadmat(path.join(dirin, vwood+'.mat'))[vwood]
            + loadmat(path.join(dirin, vdefo+'.mat'))[vdefo]
            + loadmat(path.join(dirin, vpeat+'.mat'))[vpeat])
    else:
        datain = loadmat(path.join(dirin, vin+'.mat'))[vin]

    # Add herbivory to respiration?
    if vin.upper() == 'RES' and ADDHER:
        datain = datain + loadmat(path.join(dirin, VARHER+'.mat'))[VARHER]

    # Reshape
    data = np.zeros_like(mask)
    data.flat[mask.flat == 1] = datain
    data = np.flipud(data)

    return data

def makeout(fout):
    dsout = xr.Dataset(
        data_vars={'NDVI':dandvi},
        attrs={'Conventions':'CF-1.9',
            'institution':'NASA Goddard Space Flight Center',
            'contact':'Brad Weir <brad.weir@nasa.gov>',
            'title':'MODIS/VIIRS daily vegetation (NDVI/fPAR) data',
            'input_files':''})
#
#            nccreate(fout,   'time', 'dimensions', {'time', inf}, ...
#                'datatype', 'int32');
#            ncwriteatt(fout, 'time', 'long_name',  'time');
#            ncwriteatt(fout, 'time', 'units',      ...
#                'days since 1980-01-01');
#            ncwrite(fout,    'time', datenum(year, 1, 1) + nt - 1 ...
#                - datenum(1980, 1, 1));
#
#            nccreate(fout, 'month', 'dimensions', {'month', NSTEPS});
#            ncwrite(fout,  'month', [1:NSTEPS]');

daycoords = {'lat':(['lat'], lat, {'long_name':'latitude', 'units':'degrees_north'}),
    'lon':(['lon'], lon, {'long_name':'longitude', 'units':'degrees_east'}),
    'time':(['time'], 0, {'long_name':'time', 'units':'days since 1980-01-01'}}

blank = np.nan * np.ones((nlat, nlon))

dandvi = xr.DataArray(data=blank.astype(np.single),
    dims=['lat','lon'], coords=coords,
    attrs={'long_name':'Normalized difference vegetation index (NDVI)',
        'units':'1'})


# Run
# ===
pout = check_call(['mkdir', '-p', DIROUT])

for year in range(YEAR0, YEARF+1):
    start = time() 
    syear = str(year)

    # Daily
    # ---
    if DODAILY:
        NSTEPS = (datetime(year+1, 1, 1) - datetime(year, 1, 1)).days

        for nt in range(NSTEPS):
            dnow = datetime(year, 1, 1) + timedelta(nt)
            smon = str(dnow.month).zfill(2)
            sday = str(dnow.day  ).zfill(2)

            dnowin  = path.join(DIRIN,  syear, smon, sday)
            dnowout = path.join(DIROUT, syear, smon)

            pout = check_call(['mkdir', '-p', dnowin])

            # Flux file
            fbit = ('MiCASA_' + VERSTR + '_flux_' + restag +
                '_daily_' + syear + smon + sday + '.nc')
            fout = path.join(dnowout, fbit)

            dsout = xr.Dataset(   )
            for nn in range(fluxes.size):
                dd = fluxes[nn]
                data  = loadcasa(dd, dnowin)
                dsout = dsout.assign({dd['name']:(['lat','lon','time'],
                    data, {'units':dd['units'], 'long_name':dd['desc']})})
            dsout.to_netdf(fout)

            # Extra file
            fbit = ('MiCASA_' + VERSTR + '_extra_' + restag +
                '_daily_' + syear + smon + sday + '.nc')
            fetc = path.join(dnowout, fbit)

            dsetc = xr.Dataset(    )
            for nn in range(extras.size):
                dd = extras[nn]
                data  = loadcasa(dd, dnowin)
                dsout = dsout.assign({dd['name']:(['lat','lon','time'],
                    data, {'units':dd['units'], 'long_name':dd['desc']})})
            dsetc.to_netdf(fetc)

    # Monthly
    # ---
    else:
        NSTEPS = 12

        for nn in range(datasets.size):
            dd = datasets[nn]
            dd['units'] = dd['units'].replace('day-1', 'month-1')

            vout = dd['name']
            fout = path.join(DIROUT, vout + '_' + restag +
                '_monthly_' + syear + '.nc')

            data  = loadcasa(dd, HEADIN)
            dsout = xr.Dataset(  )

    print('Year ' + syear + ', time used = ' + str(time()-start) + ' seconds')
