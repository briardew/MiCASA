#!/usr/bin/env python3

import sys
import xarray as xr
import numpy as np

import matplotlib.pyplot as plt
import cartopy.crs as ccrs

plt.rcParams['font.family'] = 'arial'

def main():
    ff = 'ndvi3g_geo_v1_1/ndvi3g_geo_v1_1_2015_0106.nc4'
    ds = xr.open_dataset(ff)
    lat = ds['lat'].values
    lon = ds['lon'].values
    ndvi = ds['ndvi'].values
    ndvi[ndvi == ds.attrs['_fill_val']] = np.nan
    ndvi = ndvi/10000.

    qt = np.nanquantile(ndvi, [0.02, 0.10, 0.25, 0.50, 0.75, 0.90, 0.98])
    print(qt)

    fig = plt.figure()
    ax = fig.add_subplot(projection=ccrs.LambertCylindrical())
    ax.coastlines()
    ax.contourf(lon, lat, ndvi[1,:,:], vmin=-0.3, vmax=1.0, cmap='Spectral_r',
        transform=ccrs.PlateCarree())
    ax.set_extent([-180, 180, -90, 90], crs=ccrs.PlateCarree())
    ax.gridlines(draw_labels=True, dms=True, x_inline=False, y_inline=False)
    plt.show()

if __name__ == '__main__':
    sys.exit(main())
