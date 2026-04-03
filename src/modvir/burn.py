'''
MiCASA burned area module
'''

# * Generalize to include VIIRS (will need to look for *.h5)
# * Create centers function and set type in edges & centers

from os import path
from glob import glob
from datetime import datetime, timedelta

import numpy as np
from modvir.patches import xarray as xr
import rioxarray as rxr

from modvir.config import defaults, TIME0, TUNITS, LCVAR, NTYPE
from modvir.geometry import edges, centers, singrid, sinarea
from modvir.utils import swaphead

def _regrid(dsout, headburn, headcov, headvcf, doy=None):
    # Output grid
    nlat = dsout.sizes['lat']
    nlon = dsout.sizes['lon']
    late, lone = edges(nlat, nlon)

    # Output arrays
    num  = np.zeros((nlat, nlon))
    burn = np.zeros((nlat, nlon))
    herb = np.zeros((nlat, nlon))
    wood = np.zeros((nlat, nlon))
    defo = np.zeros((nlat, nlon))
    date = np.zeros((nlat, nlon))

    # Read and regrid files in dirin
    # ---
    fwild = headburn + '*.hdf'
    flist = glob(fwild)
    if len(flist) == 0:
        raise EOFError('No files found matching ' + fwild)

    fused = []
    for ff in flist:
        fcov = swaphead(ff, headburn, headcov)
        fvcf = swaphead(ff, headburn, headvcf)

        # Can't believe we have to do this
        # h08v11, h01v07 have burning and no land cover
        if fcov is None:
            print('Missing land cover data for ' + ff)
            continue
        if fvcf is None:
            print('Missing VCF data for ' + ff)
            continue

        dsin  = rxr.open_rasterio(ff  ).squeeze(drop=True)
        dscov = rxr.open_rasterio(fcov).squeeze(drop=True)
        dsvcf = rxr.open_rasterio(fvcf).squeeze(drop=True)

        fused = fused + [ff, fcov, fvcf]

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

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsin['y'].values, dsin['x'].values)
        areain     = sinarea(dsin['y'].values, dsin['x'].values)

        burnin = areain
        herbin = areain * fherbin
        woodin = areain * ftreein * (1. - fdefoin)
        defoin = areain * ftreein * fdefoin

        # Hack to fix smearing the date
        iok = datein == doy if doy is not None else datein > 0

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

        dsin.close()
        dscov.close()
        dsvcf.close()

    # NB: Burned areas are sums, not averages
    iok = num > 0
    date[iok] = date[iok]/num[iok]

    # Recall values have a singleton time dim
    dsout['batot'].values[0,:,:]  = burn.astype(dsout['batot'].dtype)
    dsout['baherb'].values[0,:,:] = herb.astype(dsout['baherb'].dtype)
    dsout['bawood'].values[0,:,:] = wood.astype(dsout['bawood'].dtype)
    dsout['badefo'].values[0,:,:] = defo.astype(dsout['badefo'].dtype)
    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    # Assign day information if monthly output
    if doy is None:
        dsout = dsout.assign(date=(['time','lat','lon'],
            date[np.newaxis,:,:].astype(datein.dtype),
            {'units':'day of the year', 'long_name':'Day of burning'}
        ))

    return dsout

class Burn(xr.Dataset):
    '''Burned area class'''
    __slots__ = ()

    def __init__(self, dataset=None, time=defaults['date0'],
        nlat=defaults['nlat'], nlon=defaults['nlon'], ndays=1):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        tval = (time - TIME0).days
        tbvals = np.reshape([tval, tval + ndays], (1, 2))
        time_bnds = xr.DataArray(
            data=tbvals.astype(np.double), dims=['time','nv'],
            attrs={'long_name':'time bounds', 'units':TUNITS}
        )

        lat, lon = centers(nlat, nlon)

        coords = {
            'time':(['time'], np.array([tval]).astype(np.double), {
                'long_name':'time',
                'units':TUNITS,
                'calendar':'proleptic_gregorian',
                'bounds':'time_bnds',
            }),
            'lat':(['lat'], lat.astype(np.single), {
                'long_name':'latitude',
                'units':'degrees_north',
            }),
            'lon':(['lon'], lon.astype(np.single), {
                'long_name':'longitude',
                'units':'degrees_east',
            }),
        }

        nansxyt = np.nan * np.ones((1, nlat, nlon))
        batot = xr.DataArray(
            data=nansxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coords,
            attrs={'long_name':'Total burned area', 'units':'m2'},
        )
        baherb = xr.DataArray(
            data=nansxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coords,
            attrs={'long_name':'Herbaceous burned area', 'units':'m2'},
        )
        bawood = xr.DataArray(
            data=nansxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coords,
            attrs={'long_name':'Woody burned area', 'units':'m2'},
        )
        badefo = xr.DataArray(
            data=nansxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coords,
            attrs={'long_name':'Deforestation burned area', 'units':'m2'},
        )

        tend = time + timedelta(days=ndays) - timedelta(microseconds=1)
        attrs = {
            'NorthernmostLatiude':'90.0',
            'WesternmostLongitude':'-180.0',
            'SouthernmostLatitude':'-90.0',
            'EasternmostLongitude':'180.0',
            'RangeBeginningDate':time.strftime('%Y-%m-%d'),
            'RangeBeginningTime':time.strftime('%H:%M:%S.%f'),
            'RangeEndingDate':tend.strftime('%Y-%m-%d'),
            'RangeEndingTime':tend.strftime('%H:%M:%S.%f'),
        }

        self = xr.Dataset.__init__(self, data_vars={
            'time_bnds':time_bnds, 'batot':batot, 'baherb':baherb,
            'bawood':bawood, 'badefo':badefo,
        }, attrs=attrs)

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)
