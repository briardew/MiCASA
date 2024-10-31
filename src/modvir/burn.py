'''
MODIS/VIIRS burned area module
'''

# * Generalize to include VIIRS (will need to look for *.h5)
# * Create centers function and set type in edges & centers

from os import path
from glob import glob
from datetime import datetime

import numpy as np
import xarray as xr
import rioxarray as rxr

from modvir.config import defaults, LCVAR, NTYPE
from modvir.geometry import edges, centers, singrid, sinarea
from modvir.utils import swaphead

def _regrid(dsout, dirin, headburn, headcov, headvcf):
    # Set up output grid
    nlat = dsout.sizes['lat']
    nlon = dsout.sizes['lon']

    late, lone = edges(nlat, nlon)

    # Allocate arrays
    num  = np.zeros((nlat, nlon))
    burn = np.zeros((nlat, nlon))
    herb = np.zeros((nlat, nlon))
    wood = np.zeros((nlat, nlon))
    defo = np.zeros((nlat, nlon))
    date = np.zeros((nlat, nlon))

    # Get files to process and return if none
    flist = glob(path.join(dirin, '*.hdf'))
    if len(flist) == 0:
        return dsout

    fused = flist
    for ff in flist:
        fcov = swaphead(ff, headburn, headcov)
        fvcf = swaphead(ff, headburn, headvcf)

        # h08v11, h01v07 have burning and no land cover (***FIXME***)
        if fcov is None:
            print('Missing land cover data for ' + ff)
            continue

        if fvcf is None:
            print('Missing VCF data for ' + ff)
            continue

        fused = fused + [fcov, fvcf]

        dsin  = rxr.open_rasterio(ff  ).squeeze(drop=True)
        dscov = rxr.open_rasterio(fcov).squeeze(drop=True)
        dsvcf = rxr.open_rasterio(fvcf).squeeze(drop=True)

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsin['y'].values, dsin['x'].values)
        areain     = sinarea(dsin['y'].values, dsin['x'].values)

        datein = dsin['Burn Date'].values.T
        typein = dscov[LCVAR].values.T
        # Unclassified set to NTYPE
        typein[typein == 255] = NTYPE

        # Read VCF (percent tree and herbaceous)
        ptreehi = dsvcf['Percent_Tree_Cover']
        pherbhi = dsvcf['Percent_NonTree_Vegetation']

        # Set all water (200) and fill (253) values to barren
        ino = np.logical_or.reduce((pherbhi.values > 100, ptreehi.values > 100))
        ptreehi.values[ino] = 0
        pherbhi.values[ino] = 0

        # Coarsen VCF to burned area and land cover type grid
        ftreein = ptreehi.coarsen(x=2, y=2).mean().values.T/100.
        fherbin = pherbhi.coarsen(x=2, y=2).mean().values.T/100.

        fbothin = ftreein + fherbin
        # Make barren 50-50 split (hopefully nbd)
        ftreein[fbothin == 0.] = 0.5
        fherbin[fbothin == 0.] = 0.5
        fbothin = ftreein + fherbin

        ftreein = ftreein/fbothin
        fherbin = fherbin/fbothin

        fdefoin = typein == 2

        burnin = areain
        herbin = areain * fherbin
        woodin = areain * ftreein * (1. - fdefoin)
        defoin = areain * ftreein * fdefoin

        iok = datein > 0

        numgran  = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone))[0]
        dategran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=datein[iok])[0]
        burngran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=burnin[iok])[0]
        herbgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=herbin[iok])[0]
        woodgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=woodin[iok])[0]
        defogran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=defoin[iok])[0]

        num = num + numgran
        date = date + dategran
        burn = burn + burngran
        herb = herb + herbgran
        wood = wood + woodgran
        defo = defo + defogran

    # NB: Burned areas are sums, not averages
    iok = num > 0
    date[iok] = date[iok]/num[iok]

    # Fill Dataset
    dsout['batot'].values  = burn.astype(dsout['batot'].dtype)
    dsout['baherb'].values = herb.astype(dsout['baherb'].dtype)
    dsout['bawood'].values = wood.astype(dsout['bawood'].dtype)
    dsout['badefo'].values = defo.astype(dsout['badefo'].dtype)
    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    # Assign day information
    dsout = dsout.assign(date=(['lat','lon'], date.astype(datein.dtype),
        {'units':'day of the year', 'long_name':'Day of burning'}))

    dscov.close()

    return dsout

class Burn(xr.Dataset):
    '''Burned area class'''
    __slots__ = ()

    def __init__(self, dataset=None, nlat=defaults['nlat'],
        nlon=defaults['nlon']):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        lat, lon = centers(nlat, nlon)

        coords = {'lat':(['lat'], lat.astype(np.single),
                {'long_name':'latitude','units':'degrees_north'}),
            'lon':(['lon'], lon.astype(np.single),
                {'long_name':'longitude','units':'degrees_east'})}

        blank = np.nan * np.ones((nlat, nlon))

        batot = xr.DataArray(data=blank.astype(np.single),
            dims=['lat','lon'], coords=coords,
            attrs={'long_name':'Total burned area', 'units':'m2'})

        baherb = xr.DataArray(data=blank.astype(np.single),
            dims=['lat','lon'], coords=coords,
            attrs={'long_name':'Herbaceous burned area', 'units':'m2'})

        bawood = xr.DataArray(data=blank.astype(np.single),
            dims=['lat','lon'], coords=coords,
            attrs={'long_name':'Woody burned area', 'units':'m2'})

        badefo = xr.DataArray(data=blank.astype(np.single),
            dims=['lat','lon'], coords=coords,
            attrs={'long_name':'Deforestation burned area', 'units':'m2'})

        self = xr.Dataset.__init__(self,
            data_vars={'batot':batot, 'baherb':baherb, 'bawood':bawood,
                'badefo':badefo},
            # Read institution and contact from settings (***FIXME***)
            attrs={'Conventions':'CF-1.9',
                'institution':'NASA Goddard Space Flight Center',
                'contact':'Brad Weir <brad.weir@nasa.gov>',
                'title':'MODIS/VIIRS daily burned area data',
                'input_files':''})

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)

    def daysel(self, nd):
        ds = self.copy(deep=True)
        ds = ds.drop_vars('date')

        ino = self['date'].values != nd

        # A little hacky to prevent xarray type cast
        ds['batot'].values[ino]  = 0 * ds['batot'].values[ino]
        ds['baherb'].values[ino] = 0 * ds['baherb'].values[ino]
        ds['bawood'].values[ino] = 0 * ds['bawood'].values[ino]
        ds['badefo'].values[ino] = 0 * ds['badefo'].values[ino]

        return ds

    def to_netcdf(self, *args, **kwargs):
        # Fill history with (close enough) timestamp
        self.attrs['history'] = 'Created on ' + datetime.now().isoformat()

        # Set _FillValue to None instead of NaN by default
        if 'encoding' not in kwargs:
            kwargs['encoding'] = {var:{'_FillValue':None}
                for var in self.variables}

        return super().to_netcdf(*args, **kwargs)
