'''
MiCASA land cover type module
'''

# * Generalize to include VIIRS (will need to look for *.h5)
# * Improve type dictionary

from os import path
from glob import glob
from datetime import datetime, timedelta

import numpy as np
from modvir.patches import xarray as xr
import rioxarray as rxr

from modvir.config import defaults, TIME0, TUNITS, LCVAR, NTYPE, NMISS
from modvir.geometry import edges, centers, singrid
from modvir.utils import swaphead

def _regrid(dsout, headcov, headvcf):
    # Set up output grid
    nlat = dsout.sizes['lat']
    nlon = dsout.sizes['lon']
    late, lone = edges(nlat, nlon)

    # Output arrays
    ftype = np.zeros((NTYPE, nlat, nlon))
    num   = np.zeros((nlat, nlon))
    fbare = np.zeros((nlat, nlon))
    fherb = np.zeros((nlat, nlon))
    ftree = np.zeros((nlat, nlon))

    # Read and regrid files
    # ---
    fwild = headcov + '*.hdf'
    flist = glob(fwild)
    if len(flist) == 0:
        raise EOFError('No files found matching ' + fwild)

    fused = flist
    for ff in flist:
        dsin = rxr.open_rasterio(ff).squeeze(drop=True)

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsin['y'].values, dsin['x'].values)

        # Read land cover types
        # ---
        typein = dsin[LCVAR].values.T
        # Unclassified set to NTYPE (simplifies loops)
        typein[typein == 255] = NTYPE

        # Compute totals of each type in each cell
        for nn in range(NTYPE):
            ime = (typein == nn + 1)
            if not np.any(ime): continue

            totme = np.histogram2d(LAin[ime], LOin[ime], bins=(late,lone))[0]
            ftype[nn,:,:] = ftype[nn,:,:] + totme

        # Read VCF (percent tree, herbaceous, and barren)
        # ---
        fvcf = swaphead(ff, headcov, headvcf)
        if fvcf is None:
            print('Missing VCF data for ' + ff)
            continue
        fused = fused + [ff, fvcf]
        dsvcf = rxr.open_rasterio(fvcf).squeeze(drop=True)

        pbarehi = dsvcf['Percent_NonVegetated']
        pherbhi = dsvcf['Percent_NonTree_Vegetation']
        ptreehi = dsvcf['Percent_Tree_Cover']

        # Set all water (200) and fill (253) values to barren
        ino = np.logical_or.reduce((pbarehi.values > 100, pherbhi.values > 100,
             ptreehi.values > 100))
        pbarehi.values[ino] = 100
        pherbhi.values[ino] = 0
        ptreehi.values[ino] = 0

        # Coarsen VCF to burned area and land cover type grid
        fbarein = pbarehi.coarsen(x=2, y=2).mean().values.T/100.
        fherbin = pherbhi.coarsen(x=2, y=2).mean().values.T/100.
        ftreein = ptreehi.coarsen(x=2, y=2).mean().values.T/100.

        iok = fbarein == fbarein

        numgran   = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone))[0]
        fbaregran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=fbarein[iok])[0]
        fherbgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=fherbin[iok])[0]
        ftreegran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=ftreein[iok])[0]

        num   = num   + numgran
        fbare = fbare + fbaregran
        fherb = fherb + fherbgran
        ftree = ftree + ftreegran

        dsin.close()
        dsvcf.close()

    # Set missing tiles to type NMISS (ocean)
    tots = np.sum(ftype, axis=0)
    fmiss = ftype[NMISS,:,:]
    fmiss[tots == 0] = 1
    ftype[NMISS,:,:] = fmiss

    # Convert to fractions
    tots = np.sum(ftype, axis=0)
    for nn in range(NTYPE):
        ftype[nn,:,:] = ftype[nn,:,:]/tots

    iok = num > 0
    fbare[iok] = fbare[iok]/num[iok]
    fherb[iok] = fherb[iok]/num[iok]
    ftree[iok] = ftree[iok]/num[iok]

    mode = 1 + np.argmax(ftype, axis=0)

    # Recall values have a singleton time dim
    dsout['ftype'].values[0,:,:,:] = ftype.astype(dsout['ftype'].dtype)
    dsout['fbare'].values[0,:,:] = fbare.astype(dsout['fbare'].dtype)
    dsout['fherb'].values[0,:,:] = fherb.astype(dsout['fherb'].dtype)
    dsout['ftree'].values[0,:,:] = ftree.astype(dsout['ftree'].dtype)
    dsout['mode'].values[0,:,:] = mode.astype(dsout['mode'].dtype)

    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    return dsout

class Cover(xr.Dataset):
    '''MiCASA land cover type class'''
    __slots__ = ()

    def __init__(self, dataset=None, time=defaults['date0'],
        nlat=defaults['nlat'], nlon=defaults['nlon']):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        year = time.year
        tval = (datetime(year, 1, 1) - TIME0).days
        yrdays = (datetime(year+1, 1, 1) - datetime(year, 1, 1)).days
        tbvals = np.reshape([tval, tval + yrdays], (1, 2))
        time_bnds = xr.DataArray(
            data=tbvals.astype(np.double), dims=['time','nv'],
            attrs={'long_name':'time bounds', 'units':TUNITS}
        )

        typedim = np.linspace(1, NTYPE, NTYPE)

        lat, lon = centers(nlat, nlon)

        coords = {
            'time':(['time'], np.array([tval]).astype(np.double), {
                'long_name':'time',
                'units':TUNITS,
                'calendar':'proleptic_gregorian',
                'bounds':'time_bnds',
            }),
            'type':(['type'], typedim.astype(np.short), {
                'long_name':'land cover type',
                'units':'none',
                # Better way to do this?
                '1':'Evergreen Needleleaf Forests',
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
                '18':'Unclassified',
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
        coordsxyt = {'time':coords['time'],
            'lat':coords['lat'], 'lon':coords['lon']}

        ftype = xr.DataArray(
            data=np.zeros((1, NTYPE, nlat, nlon)).astype(np.single),
            dims=['time','type','lat','lon'], coords=coords,
            attrs={'long_name':'Fraction land cover type', 'units':'%'},
        )

        zerosxyt = np.zeros((1, nlat, nlon))
        fbare = xr.DataArray(
            data=zerosxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coordsxyt,
            attrs={'long_name':'Fraction bare ground cover', 'units':'1'},
        )
        fherb = xr.DataArray(
            data=zerosxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coordsxyt,
            attrs={'long_name':'Fraction herbaceous cover', 'units':'1'},
        )
        ftree = xr.DataArray(
            data=zerosxyt.astype(np.single),
            dims=['time','lat','lon'], coords=coordsxyt,
            attrs={'long_name':'Fraction tree cover', 'units':'1'},
        )

        onesxyt = np.ones((1, nlat, nlon))
        mode = xr.DataArray(
            data=onesxyt.astype(np.short),
            dims=['time','lat','lon'], coords=coordsxyt,
            attrs={'long_name':'Most common land cover type', 'units':'none'},
        )

        tend = time + timedelta(days=yrdays) - timedelta(microseconds=1)
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
            'time_bnds':time_bnds, 'ftype':ftype, 'fbare':fbare, 'fherb':fherb,
            'ftree':ftree, 'mode':mode,
        }, attrs=attrs)

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)
