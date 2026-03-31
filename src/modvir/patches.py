'''
Monkey patches for xarray
'''

import xarray
from datetime import datetime

xarray.Dataset._to_netcdf_old = xarray.Dataset.to_netcdf
def _to_netcdf_new(self, *args, **kwargs):
    # By default set _FillValue to None instead of NaN and turn on compression
    # Note: kwargs['encoding'] overwrites DataArray.encoding
    encoding0 = {'_FillValue':None, 'zlib':True, 'complevel':9}
    for var in self.variables:
        self.variables[var].encoding = {**encoding0,
            **self.variables[var].encoding}

    # If kwargs['encoding'] is set, but has no _FillValue, it will ignore
    # DataArray.encoding (maybe an actual bug?)
    if 'encoding' in kwargs:
        encoding = kwargs['encoding']
        for var in self.variables:
            encoding[var] = {**self.variables[var].encoding,
                **encoding.get(var, {})}
        kwargs['encoding'] = encoding

    # Fill history with (close enough) timestamp
    self.attrs['history'] = 'Created on ' + datetime.now().isoformat()

    self._to_netcdf_old(*args, **kwargs)
xarray.Dataset.to_netcdf = _to_netcdf_new
