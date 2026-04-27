'''
MiCASA burned area module
'''

from os import path, makedirs, remove, rmdir
from glob import glob
from datetime import datetime, timedelta
from calendar import monthrange

import numpy as np
import rioxarray as rxr
from modvir.patches import xarray as xr

from modvir import cover
from modvir.config import FEXT, TIME0, TUNITS, LCVAR, NTYPE, fillargs
from modvir.geometry import edges, centers, singrid, sinarea
from modvir.utils import download, swaphead, tidy

def get(dtval, **kwargs):
    '''Acquire MODIS/VIIRS burned area tiles'''

    kwargs = fillargs(dtval, **kwargs)
    colburn = kwargs['colburn']
    headburn = kwargs['headburn']

    files = download(dtval, colburn, path.dirname(headburn), kwargs['force'])

    if len(files) == 0:
        raise EOFError(f'No granules found for {colburn} on {dtval:%Y-%m-%d}')

    return files

def regrid(dtval, doy=None, **kwargs):
    '''Regrid MODIS/VIIRS burned area'''

    # Process arguments
    # ---
    kwargs = fillargs(dtval, **kwargs)

    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    ver = kwargs['ver']
    vernum, _, verdom = ver.partition('-')

    # Define coordinates
    # ---
    tval = (dtval - TIME0).days
    if doy is not None:
        ndays = 1
    else:
        ndays = monthrange(dtval.year, dtval.month)[1]
    tbvals = np.reshape([tval, tval + ndays], (1, 2))
    time_bnds = xr.DataArray(
        data=tbvals.astype(np.double), dims=['time','nv'],
        attrs={'long_name':'time bounds'}
    )

    lat, lon = centers(nlat, nlon, verdom)
    late, lone = edges(nlat, nlon, verdom)

    coords = {
        'time':(['time'], np.array([tval]).astype(np.double), {
            'long_name':'time',
            'units':TUNITS,
            'calendar':'proleptic_gregorian',
            'bounds':'time_bnds',
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

    # Define data arrays
    # ---
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

    # Define attributes
    # ---
    if doy is not None:
        shortname = 'MICASA_BURN_D'
        longname = ('MiCASA Daily Burned Area ' +
            f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    else:
        shortname = 'MICASA_BURN_M'
        longname = ('MiCASA Monthly Burned Area ' +
            f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    dtend = dtval + timedelta(days=ndays) - timedelta(microseconds=1)

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
        'time_bnds':time_bnds, 'batot':batot, 'baherb':baherb,
        'bawood':bawood, 'badefo':badefo,
    }, attrs=attrs)

    # Just give the empty structure if not regridding
    if not kwargs['regrid']: return ds

    # Read and regrid files in dirin
    # ---
    files = get(dtval, **kwargs)
    filescov, filesvcf = cover.get(datetime(dtval.year, 1, 1), **kwargs)

    num  = np.zeros((nlat, nlon))
    burn = np.zeros((nlat, nlon))
    herb = np.zeros((nlat, nlon))
    wood = np.zeros((nlat, nlon))
    defo = np.zeros((nlat, nlon))
    date = np.zeros((nlat, nlon))

    fused = []
    for ff in files:
        fcov = swaphead(ff, kwargs['headburn'], kwargs['headcov'])
        fvcf = swaphead(ff, kwargs['headburn'], kwargs['headvcf'])

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

        # Use doy if specified, otherwise average over month
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
    ds['batot'].values[0,:,:]  = burn.astype(ds['batot'].dtype)
    ds['baherb'].values[0,:,:] = herb.astype(ds['baherb'].dtype)
    ds['bawood'].values[0,:,:] = wood.astype(ds['bawood'].dtype)
    ds['badefo'].values[0,:,:] = defo.astype(ds['badefo'].dtype)
    ds.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    # Assign day information if monthly output
    if doy is None:
        ds = ds.assign(date=(['time','lat','lon'],
            date[np.newaxis,:,:].astype(datein.dtype),
            {'units':'day of the year', 'long_name':'Day of burning'}
        ))

    return ds

def build(dtbeg, dtend, **kwargs):
    '''Build MODIS/VIIRS burned area'''

    print('===    ____ Burned Area')

    for year in range(dtbeg.year, dtend.year+1):
        print(f'===    ________ {year}')

        # Process arguments
        # ---
        dtyear = datetime(year, 1, 1)
        kwyear = fillargs(dtyear, **kwargs)

        ver = kwyear['ver']
        domtag = kwyear['domtag']
        output = kwyear['output']

        # Output vars
        dirout  = path.join(output, 'burn', f'{year}')
        headmon = path.join(dirout, f'MiCASA_v{ver}_burn_{domtag}_monthly_')
        headday = path.join(dirout, f'MiCASA_v{ver}_burn_{domtag}_daily_')

        # Build burned area
        # ---
        for nm in range(1,13):
            # Skip if outside range
            if year == dtbeg.year and nm < dtbeg.month:
                continue
            elif year == dtend.year and dtend.month < nm:
                continue

            # Process arguments
            # ---
            dtmon = datetime(year, nm, 1)
            kwmon = fillargs(dtmon, **kwargs)

            headburn = kwmon['headburn']

            doget = kwmon['get']
            doregrid = kwmon['regrid']
            doforce = kwmon['force']
            dotidy = kwmon['tidy']

            print('===    ________ ' + dtmon.strftime('%Y-%m'))

            # Output vars
            fmon = headmon + dtmon.strftime('%Y%m') + '.' + FEXT

            # Download if requested or needed for regrid
            get4regrid = doregrid and (not path.isfile(fmon) or doforce)
            if get4regrid or doget:
                print('===    ____________ Downloading')
                get(dtmon, **kwmon)

            if doregrid:
                # Regrid monthlies
                print('===    ____________ Regridding')

                if path.isfile(fmon) and not doforce:
                    dsmon = xr.open_dataset(fmon)
                else:
                    dsmon = regrid(dtmon, None, **kwmon)
                    makedirs(dirout, exist_ok=True)
                    dsmon.to_netcdf(fmon, unlimited_dims=['time'])

                # Output dailies
                ndays = monthrange(year, nm)[1]
                for nd in range(1,ndays+1):
                    dtnow = datetime(year, nm, nd)
                    kwnow = fillargs(dtnow, **kwargs)
                    doy = (dtnow - datetime(year, 1, 1)).days + 1
                    fday = headday + dtnow.strftime('%Y%m%d') + '.' + FEXT
                    if not path.isfile(fday) or doforce: 
                        if ver == '1':
                            # Hack to preserve v1 "bug" that averaged burn dates
                            ds = regrid(dtnow, doy, **{**kwnow, 'regrid':False})

                            nd = (dtnow - dtyear).days + 1
                            iok = dsmon['date'].values == nd
                            ino = dsmon['date'].values != nd

                            for var in ['batot', 'baherb', 'bawood', 'badefo']:
                                ds[var].values[iok] = dsmon[var].values[iok]
                                ds[var].values[ino] = dsmon[var].values[ino]*0
                            ds.attrs['input_files'] = dsmon.attrs['input_files']
                        else:
                            ds = regrid(dtnow, doy, **kwnow)

                        ds.to_netcdf(fday, unlimited_dims=['time'])

                    # Finished?
                    if dtnow == dtend: break

            # Slightly terrifying
            if dotidy: tidy(headburn)

            # Finished?
            if dtnow == dtend: break

        # Slightly terrifying
        if dotidy and doregrid:
            tidy(headcov)
            tidy(headvcf)

    # Not sure why this is here of it's useful
    return ds
