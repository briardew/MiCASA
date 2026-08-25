from datetime import datetime
from modvir.patches import xarray as xr
import numpy as np

YEAR0 = 1980                                                    # Year that all timestamps are based on
TIME0 = datetime(YEAR0, 1, 1)                                   # YEAR0 in datetime format
TUNITS = 'days since ' + TIME0.strftime('%Y-%m-%d')             # Time units string

# variables in original code
ndays = 1
nlat = 1800
nlon = 3600

for nd in range(20):
    dtnow = datetime(2026, 7, nd + 1)

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

    ff = f'MiCASA_vNRT_vegind_x{nlon}_y{nlat}_daily_202607{nd+1:02}.nc4'
    ds = xr.open_dataset(ff)
    ds = ds.expand_dims(time=np.array([tnow]).astype(np.double))
    ds['time'].attrs = timeattrs

    ds['time_bnds'] = time_bnds

    qclong = 'Quality control variable (greater = better)'
    ds['QC'] = (['time', 'lat', 'lon'], 0.5 * np.ones((1, nlat, nlon)))
    ds['QC'].attrs = {'long_name': qclong, 'units': '1'}

    ds.to_netcdf(ff)
