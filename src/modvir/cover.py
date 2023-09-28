'''
MODIS/VIIRS land cover type module
'''

# * Generalize to include VIIRS (will need to look for *.h5)
# * Copy type dictionary somehow

from os import path
from glob import glob
from datetime import datetime

import numpy as np
import xarray as xr
import rioxarray as rxr

from modvir.config import defaults, LCVAR, NTYPE, NMISS
from modvir.geometry import edges, centers, singrid

def _regrid(dsout, dirin):
    nlat = dsout.sizes['lat']
    nlon = dsout.sizes['lon']

    late, lone = edges(nlat, nlon)

    flist = glob(path.join(dirin, '*.hdf'))
    if len(flist) == 0:
        raise EOFError('no files to open')

    percent = np.zeros((NTYPE, nlat, nlon))
    for ff in flist:
        dsin = rxr.open_rasterio(ff).squeeze(drop=True)

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsin['y'].values, dsin['x'].values)

        typein = dsin[LCVAR].values.T
        # Unclassified set to NTYPE (simplifies loops)
        typein[typein == 255] = NTYPE

        # Compute totals of each type in each cell
        # ----------------------------------------
        for nn in range(NTYPE):
            ime = (typein == nn + 1)
            if not np.any(ime): continue

            totme = np.histogram2d(LAin[ime], LOin[ime], bins=(late,lone))[0]
            percent[nn,:,:] = percent[nn,:,:] + totme
    dsin.close()

    # Set missing tiles to type NMISS (ocean)
    tots = np.sum(percent, axis=0)
    temp = percent[NMISS,:,:]
    temp[tots == 0] = 1
    percent[NMISS,:,:] = temp 

    # Convert to percentages
    tots = np.sum(percent, axis=0)
    for nn in range(NTYPE):
        percent[nn,:,:] = percent[nn,:,:]/tots

    dsout['percent'].values = percent.astype(dsout['percent'].dtype)
    dsout['mode'].values = 1 + np.argmax(percent, axis=0).astype(dsout['mode'].dtype)

    # Better way to do this?
    dsout['mode'].attrs = {'1':'Evergreen Needleleaf Forests',
        '2':'Evergreen Broadleaf Forests',
        '3':'Deciduous Needleleaf Forests',
        '4':'Deciduous Broadleaf Forests',
        '5':'Mixed Forests',
        '6':'Closed Shrublands',
        '7':'Open Shrublands',
        '8':'Woody Savannas',
        '9':'Savannas',
        '10':'Grasslands',
        '11':'Permanent Wetlands',
        '12':'Croplands',
        '13':'Urban and Built-up Lands',
        '14':'Cropland/Natural Vegetation Mosaics',
        '15':'Permanent Snow and Ice',
        '16':'Barren',
        '17':'Water Bodies',
        '18':'Unclassified'}

    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in flist])

    return dsout

class Cover(xr.Dataset):
    '''MODIS/VIIRS land cover type class'''
    __slots__ = ()

    def __init__(self, dataset=None, nlat=defaults['nlat'],
        nlon=defaults['nlon']):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        lat, lon = centers(nlat, nlon)
        typedim = np.linspace(1, NTYPE, NTYPE)

        coords = {'type':(['type'], typedim.astype(np.short),
                {'long_name':'land cover type','units':'none'}),
            'lat':(['lat'], lat.astype(np.single),
                {'long_name':'latitude','units':'degrees north'}),
            'lon':(['lon'], lon.astype(np.single),
                {'long_name':'longitude','units':'degrees east'})}

        percent = np.zeros((NTYPE, nlat, nlon))

        dapct = xr.DataArray(data=percent.astype(np.single),
            dims=['type','lat','lon'], coords=coords,
            attrs={'long_name':'Percentage of land cover type',
                'units':'%'})

        mode = np.ones((nlat, nlon))

        damode = xr.DataArray(data=mode.astype(np.short),
            dims=['lat','lon'],
            coords={'lat':coords['lat'], 'lon':coords['lon']},
            attrs={'long_name':'Most common land cover type',
                'units':'none'})

        self = xr.Dataset.__init__(self,
            data_vars={'percent':dapct, 'mode':damode},
            attrs={'Conventions':'CF-1.9',
                'title':'MODIS/VIIRS annual land cover type data',
                'institution':'NASA GMAO Constituent Group',
                'contact':'Brad Weir <brad.weir@nasa.gov>',
                'input_files':''})

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)

    def to_netcdf(self, *args, **kwargs):
        # Fill history with (close enough) timestamp
        self.attrs['history'] = 'Created on ' + datetime.now().isoformat()

        # Set _FillValue to None instead of NaN by default
        if 'encoding' not in kwargs:
            kwargs['encoding'] = {var:{'_FillValue':None}
                for var in self.variables}

        return super().to_netcdf(*args, **kwargs)
