'''
MODIS/VIIRS land cover module
'''

import sys
from os import path, makedirs, remove, rmdir
from glob import glob
from datetime import datetime, timedelta

import numpy as np
import rioxarray as rxr
from modvir.patches import xarray as xr

from modvir.config import FEXT, TIME0, TUNITS, LCVAR, NTYPE, NMISS, fillargs
from modvir.geometry import edges, centers, singrid
from modvir.utils import download, swaphead, tidy

def get(dtval, **kwargs):
    '''Acquire MODIS/VIIRS land cover tiles'''

    kwargs = fillargs(dtval, **kwargs)
    colcov = kwargs['colcov']
    colvcf = kwargs['colvcf']
    headcov = kwargs['headcov']
    headvcf = kwargs['headvcf']

    # Bit of a hack, wish we could keep this in one place
    dtvcf = datetime(dtval.year, 1, 1) + timedelta(days=64)

    filescov = download(dtval, colcov, path.dirname(headcov), kwargs['force'])
    filesvcf = download(dtvcf, colvcf, path.dirname(headvcf), kwargs['force'])

    if len(filescov) == 0:
        raise EOFError(f'No granules found for {colcov} on {dtval:%Y-%m-%d}')
    elif len(filesvcf) == 0:
        # MOD44B is missing/broken on CMR, need to manually copy for now
#       raise EOFError(f'No granules found for {colvcf} on {dtvcf:%Y-%m-%d}')
        print(f'No files found for {colvcf} on {dtvcf:%Y-%m-%d}',
            file=sys.stderr)

    return filescov, filesvcf

def regrid(dtval, **kwargs):
    '''Regrid MODIS/VIIRS land cover'''

    # Process arguments
    # ---
    kwargs = fillargs(dtval, **kwargs)

    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    ver = kwargs['ver']
    vernum, _, verdom = ver.partition('-')

    # Define coordinates
    # ---
    year = dtval.year
    tval = (datetime(year, 1, 1) - TIME0).days
    yrdays = (datetime(year+1, 1, 1) - datetime(year, 1, 1)).days
    tbvals = np.reshape([tval, tval + yrdays], (1, 2))
    time_bnds = xr.DataArray(
        data=tbvals.astype(np.double), dims=['time','nv'],
        attrs={'long_name':'time bounds'}
    )

    typedim = np.linspace(1, NTYPE, NTYPE)

    lat, lon = centers(nlat, nlon, verdom)
    late, lone = edges(nlat, nlon, verdom)

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
        'lat':(['lat'], lat.astype(np.double), {
            'long_name':'latitude',
            'units':'degrees_north',
        }),
        'lon':(['lon'], lon.astype(np.double), {
            'long_name':'longitude',
            'units':'degrees_east',
        }),
    }
    coordsxyt = {'time':coords['time'],
        'lat':coords['lat'], 'lon':coords['lon']}

    # Define data arrays
    # ---
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

    # Define attributes
    # ---
    shortname = 'MICASA_COVER_Y'
    longname = ('MiCASA Yearly Land Cover ' +
        f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    dtend = dtval + timedelta(days=yrdays) - timedelta(microseconds=1)

    # Strange syntax so attributes are in desired order
    attrs = {
        'ShortName':shortname,
        'LongName':longname,
        'title':f'{longname} v{ver}',
        'VersionID':ver,
    }
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact']:
        if key in kwargs: attrs[key] = kwargs[key]
    attrs = {
        **attrs, 
        'NorthernmostLatiude':'90.0',
        'WesternmostLongitude':'-180.0',
        'SouthernmostLatitude':'-90.0',
        'EasternmostLongitude':'180.0',
        'RangeBeginningDate':dtval.strftime('%Y-%m-%d'),
        'RangeBeginningTime':dtval.strftime('%H:%M:%S.%f'),
        'RangeEndingDate':dtend.strftime('%Y-%m-%d'),
        'RangeEndingTime':dtend.strftime('%H:%M:%S.%f'),
    }

    ds = xr.Dataset(data_vars={
        'time_bnds':time_bnds, 'ftype':ftype, 'fbare':fbare, 'fherb':fherb,
        'ftree':ftree, 'mode':mode,
    }, attrs=attrs)

    # Just give the empty structure if not regridding
    if not kwargs['regrid']: return ds

    # Read and regrid files
    # ---
    filescov, filesvcf = get(dtval, **kwargs)

    ftype = np.zeros((NTYPE, nlat, nlon))
    num   = np.zeros((nlat, nlon))
    fbare = np.zeros((nlat, nlon))
    fherb = np.zeros((nlat, nlon))
    ftree = np.zeros((nlat, nlon))

    fused = filescov
    for ff in filescov:
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
        fvcf = swaphead(ff, kwargs['headcov'], kwargs['headvcf'])
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
    # Type cast is to prevent xarray from casting :(
    ds['ftype'].values[0,:,:,:] = ftype.astype(ds['ftype'].dtype)
    ds['fbare'].values[0,:,:] = fbare.astype(ds['fbare'].dtype)
    ds['fherb'].values[0,:,:] = fherb.astype(ds['fherb'].dtype)
    ds['ftree'].values[0,:,:] = ftree.astype(ds['ftree'].dtype)
    ds['mode'].values[0,:,:] = mode.astype(ds['mode'].dtype)

    ds.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    return ds

def build(dtbeg, dtend, **kwargs):
    '''Build MODIS/VIIRS land cover'''

    print('===    ____ Land Cover')

    for year in range(dtbeg.year, dtend.year+1):
        print(f'===    ________ {year}')

        # Process arguments
        # ---
        dtnow = datetime(year, 1, 1)
        kwnow = fillargs(dtnow, **kwargs)

        ver = kwnow['ver']
        domtag = kwnow['domtag']
        output = kwnow['output']
        headcov = kwnow['headcov']
        headvcf = kwnow['headvcf']

        doget = kwnow['get']
        doregrid = kwnow['regrid']
        doforce = kwnow['force']
        dotidy = kwnow['tidy']

        # Output vars
        dirout = path.join(output, 'cover')
        fgran  = f'MiCASA_v{ver}_cover_{domtag}_yearly_{year}.{FEXT}'
        fout   = path.join(dirout, fgran)

        # Download if needed for regrid or requested
        get4regrid = doregrid and (not path.isfile(fout) or doforce)
        if get4regrid or doget:
            print('===    ____________ Downloading')
            filescov, filesvcf = get(dtnow, **kwnow)

        if doregrid:
            print('===    ____________ Regridding')
            if path.isfile(fout) and not doforce:
                ds = xr.open_dataset(fout)
            else:
                ds = regrid(dtnow, **kwnow)
                makedirs(dirout, exist_ok=True)
                ds.to_netcdf(fout, unlimited_dims=['time'])

        # Slightly terrifying
        if dotidy:
            tidy(headcov)
            tidy(headvcf)

    return ds
