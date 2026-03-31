'''
MiCASA land cover type module
'''

# * Generalize to include VIIRS (will need to look for *.h5)
# * Improve type dictionary

from os import path
from glob import glob
from datetime import datetime

import numpy as np
from modvir.patches import xarray as xr
import rioxarray as rxr

from modvir.config import defaults, LCVAR, NTYPE, NMISS
from modvir.geometry import edges, centers, singrid
from modvir.utils import swaphead

def _regrid(dsout, dirin, headcov, headvcf):
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

    # Read and regrid files in dirin
    # ---
    flist = glob(path.join(dirin, '*.hdf'))
    if len(flist) == 0:
        raise EOFError('No files found in ' + dirin)

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

    dsout['ftype'].values = ftype.astype(dsout['ftype'].dtype)
    dsout['mode'].values = 1 + np.argmax(ftype, axis=0).astype(dsout['mode'].dtype)

    # Better way to do this?
    dsout['ftype'].attrs = {
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
        '18':'Unclassified'}

    dsout['fbare'].values = fbare.astype(dsout['fbare'].dtype)
    dsout['fherb'].values = fherb.astype(dsout['fherb'].dtype)
    dsout['ftree'].values = ftree.astype(dsout['ftree'].dtype)

    # Change flist to fused that includes VCF
    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    return dsout

class Cover(xr.Dataset):
    '''MiCASA land cover type class'''
    __slots__ = ()

    def __init__(self, dataset=None, nlat=defaults['nlat'],
        nlon=defaults['nlon']):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        lat, lon = centers(nlat, nlon)
        typedim = np.linspace(1, NTYPE, NTYPE)

        coords = {
            'type':(['type'], typedim.astype(np.short),
                {'long_name':'land cover type','units':'none'}),
            'lat':(['lat'], lat.astype(np.single),
                {'long_name':'latitude','units':'degrees_north'}),
            'lon':(['lon'], lon.astype(np.single),
                {'long_name':'longitude','units':'degrees_east'}),
        }
        coordsxy = {'lat':coords['lat'], 'lon':coords['lon']}

        zerosxyn = np.zeros((NTYPE, nlat, nlon))
        ftype = xr.DataArray(
            data=zerosxyn.astype(np.single),
            dims=['type','lat','lon'], coords=coords,
            attrs={'long_name':'Percentage of land cover type', 'units':'%'},
        )

        onesxy = np.ones((nlat, nlon))
        mode = xr.DataArray(
            data=onesxy.astype(np.short),
            dims=['lat','lon'], coords=coordsxy,
            attrs={'long_name':'Most common land cover type', 'units':'none'},
        )

        zerosxy = np.zeros((nlat, nlon))
        fbare = xr.DataArray(
            data=zerosxy.astype(np.single),
            dims=['lat','lon'], coords=coordsxy,
            attrs={'long_name':'Fraction bare ground cover', 'units':'1'},
        )
        fherb = xr.DataArray(
            data=zerosxy.astype(np.single),
            dims=['lat','lon'], coords=coordsxy,
            attrs={'long_name':'Fraction herbaceous cover', 'units':'1'},
        )
        ftree = xr.DataArray(
            data=zerosxy.astype(np.single),
            dims=['lat','lon'], coords=coordsxy,
            attrs={'long_name':'Fraction tree cover', 'units':'1'},
        )

        self = xr.Dataset.__init__(self,
            data_vars={'ftype':ftype, 'mode':mode, 'fbare':fbare,
                'fherb':fherb, 'ftree':ftree})

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)
