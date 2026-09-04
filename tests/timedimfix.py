from datetime import datetime
from modvir.patches import xarray as xr
from modvir.vegind import regrid
import numpy as np

YEAR0 = 1980  # Year that all timestamps are based on
TIME0 = datetime(YEAR0, 1, 1)  # YEAR0 in datetime format
TUNITS = 'days since ' + TIME0.strftime('%Y-%m-%d')  # Time units string

# variables in original code
ndays = 1
nlat = 1800
nlon = 3600

year = 2026
mon = 7
dcut = 21

fhead = f'MiCASA_vNRT_vegind_x{nlon}_y{nlat}'


def fixll(ds):
    ds.coords['lat'] = ds.coords['lat'].astype(np.single)
    ds.coords['lon'] = ds.coords['lon'].astype(np.single)
    return ds


for nd in range(1, dcut):
    dtnow = datetime(year, mon, nd)

    tnow = (dtnow - TIME0).days
    tbnow = np.reshape([tnow, tnow + ndays], (1, 2))
    time_bnds = xr.DataArray(
        data=tbnow.astype(np.double),
        dims=['time', 'nv'],
        attrs={'long_name': 'time bounds'},
    )

    timeattrs = {
        'long_name': 'time',
        'units': TUNITS,
        'calendar': 'proleptic_gregorian',
        'bounds': 'time_bnds',
    }

    ff = f'{fhead}_daily_{year}{mon:02}{nd + 1:02}.nc4'
    ds = xr.open_dataset(ff)
    ds = ds.expand_dims(time=np.array([tnow]).astype(np.double))
    ds['time'].attrs = timeattrs

    ds['time_bnds'] = time_bnds

    qclong = 'Quality control variable (greater = better)'
    ds['QC'] = (['time', 'lat', 'lon'], 0.5 * np.ones((1, nlat, nlon)))
    ds['QC'].attrs = {'long_name': qclong, 'units': '1'}

    ds.to_netcdf(ff)

fin = f'{fhead}_daily_{year}{mon:02}*.nc4'
fout = f'{fhead}_monthly_{year}{mon:02}.nc4'
with xr.open_mfdataset(fin, preprocess=fixll) as dsin:
    # I try not to do this (dtmon & dsmon), but alas
    dtmon = datetime(year, mon, 1)
    dsmon = regrid(dtmon, monthly=True)

    # Different versions of xarray return different things for
    # `Dataset.mean`. Better to just do the average and replace arrays
    # in an exisiting dataset
    dsavg = dsin.mean(dim='time').expand_dims('time')
    for var in dsavg.data_vars:
        dsmon[var].values = dsavg[var].values
    dsmon.to_netcdf(fout, unlimited_dims=['time'])
