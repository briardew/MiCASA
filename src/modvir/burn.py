"""
MODIS/VIIRS burned area module
"""

from os import path, makedirs
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


def get(dtnow, **kwargs):
    """Acquire MODIS/VIIRS burned area tiles"""

    kwnow = fillargs(dtnow, **kwargs)
    headburn = kwnow['headburn']
    dirburn = path.dirname(headburn)
    granburn = path.basename(headburn)

    # Check for local copies first (earthaccess is flaky)
    files = glob(headburn)
    if len(files) == 0 or kwnow['force']:
        files = download(granburn, dirburn, kwnow['force'])
    if len(files) == 0:
        raise EOFError('No granules found matching ' + granburn)

    return files


def regrid(dtnow, monthly=False, **kwargs):
    """Regrid MODIS/VIIRS burned area"""

    # Process arguments
    # ---
    kwnow = fillargs(dtnow, **kwargs)

    nlat = kwnow['nlat']
    nlon = kwnow['nlon']
    product = kwnow['product']
    ver = kwnow['ver']
    # Split full version (###-XYZ) into number (###) and domain (XYZ)
    vernum, _, domain = ver.partition('-')

    # Define coordinates
    # ---
    tnow = (dtnow - TIME0).days
    if not monthly:
        ndays = 1
    else:
        ndays = monthrange(dtnow.year, dtnow.month)[1]
    tbnow = np.reshape([tnow, tnow + ndays], (1, 2))
    time_bnds = xr.DataArray(
        data=tbnow.astype(np.double),
        dims=['time', 'nv'],
        attrs={'long_name': 'time bounds'},
    )

    lat, lon = centers(nlat, nlon, domain)
    late, lone = edges(nlat, nlon, domain)

    timeattrs = {
        'long_name': 'time',
        'units': TUNITS,
        'calendar': 'proleptic_gregorian',
        'bounds': 'time_bnds',
    }
    latattrs = {
        'long_name': 'latitude',
        'units': 'degrees_north',
    }
    lonattrs = {
        'long_name': 'longitude',
        'units': 'degrees_east',
    }

    coords = {
        'time': (['time'], np.array([tnow]).astype(np.double), timeattrs),
        'lat': (['lat'], lat.astype(np.double), latattrs),
        'lon': (['lon'], lon.astype(np.double), lonattrs),
    }

    # Define data arrays
    # ---
    nansxyt = np.nan * np.ones((1, nlat, nlon))
    batot = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': 'Total burned area', 'units': 'm2'},
    )
    baherb = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': 'Herbaceous burned area', 'units': 'm2'},
    )
    bawood = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': 'Woody burned area', 'units': 'm2'},
    )
    badefo = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': 'Deforestation burned area', 'units': 'm2'},
    )

    # Define attributes
    # ---
    reslong = (
        f'{round(late[1] - late[0], 3)} degree x '
        + f'{round(lone[1] - lone[0], 3)} degree'
    )
    if not monthly:
        shortname = f'{product.upper()}_BURN_D'
        longname = f'{product} Daily Burned Area {reslong}'
    else:
        shortname = f'{product.upper()}_BURN_M'
        longname = f'{product} Monthly Burned Area {reslong}'
    dtend = dtnow + timedelta(days=ndays) - timedelta(microseconds=1)

    # Strange syntax so attributes are in desired order
    attrs = {
        'ShortName': shortname,
        'LongName': longname,
        'title': f'{longname} v{ver}',
        'VersionID': ver,
    }
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution', 'contact']:
        if key in kwnow:
            attrs[key] = kwnow[key]
    attrs = {
        **attrs,
        'SouthernmostLatitude': f'{np.min(late)}',
        'NorthernmostLatiude': f'{np.max(late)}',
        'WesternmostLongitude': f'{np.min(lone)}',
        'EasternmostLongitude': f'{np.max(lone)}',
        'RangeBeginningDate': dtnow.strftime('%Y-%m-%d'),
        'RangeBeginningTime': dtnow.strftime('%H:%M:%S.%f'),
        'RangeEndingDate': dtend.strftime('%Y-%m-%d'),
        'RangeEndingTime': dtend.strftime('%H:%M:%S.%f'),
    }

    ds = xr.Dataset(
        data_vars={
            'time_bnds': time_bnds,
            'batot': batot,
            'baherb': baherb,
            'bawood': bawood,
            'badefo': badefo,
        },
        attrs=attrs,
    )

    # Just give the empty structure if not regridding
    if not kwnow['regrid']:
        return ds

    # Read and regrid files in dirin
    # ---
    files = get(dtnow, **kwnow)
    filescov, filesvcf = cover.get(datetime(dtnow.year, 1, 1), **kwnow)

    num = np.zeros((nlat, nlon))
    burn = np.zeros((nlat, nlon))
    herb = np.zeros((nlat, nlon))
    wood = np.zeros((nlat, nlon))
    defo = np.zeros((nlat, nlon))
    date = np.zeros((nlat, nlon))

    fused = []
    for ff in files:
        fcov = swaphead(ff, filescov)
        fvcf = swaphead(ff, filesvcf)

        # Can't believe we have to do this
        # h08v11, h01v07 have burning and no land cover
        if fcov is None:
            print('Missing land cover data for ' + ff)
            continue
        if fvcf is None:
            print('Missing VCF data for ' + ff)
            continue

        dsin = rxr.open_rasterio(ff).squeeze(drop=True)
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
        ftreein = ptreehi.coarsen(x=2, y=2).mean().values.T / 100.0
        fherbin = pherbhi.coarsen(x=2, y=2).mean().values.T / 100.0

        fbothin = ftreein + fherbin
        # Make barren 50-50 split (hopefully nbd)
        ftreein[fbothin == 0.0] = 0.5
        fherbin[fbothin == 0.0] = 0.5
        fbothin = ftreein + fherbin

        ftreein = ftreein / fbothin
        fherbin = fherbin / fbothin

        fdefoin = typein == 2

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsin['y'].values, dsin['x'].values)
        areain = sinarea(dsin['y'].values, dsin['x'].values)

        burnin = areain
        herbin = areain * fherbin
        woodin = areain * ftreein * (1.0 - fdefoin)
        defoin = areain * ftreein * fdefoin

        # Use doy if daily, otherwise use all valid dates in month
        if not monthly:
            doy = (dtnow - datetime(dtnow.year, 1, 1)).days + 1
            iok = datein == doy
        else:
            iok = datein > 0

        LAok = LAin[iok]
        LOok = LOin[iok]
        bins = (late, lone)

        numgran = np.histogram2d(LAok, LOok, bins=bins)[0]
        dategran = np.histogram2d(LAok, LOok, bins=bins, weights=datein[iok])[0]
        burngran = np.histogram2d(LAok, LOok, bins=bins, weights=burnin[iok])[0]
        herbgran = np.histogram2d(LAok, LOok, bins=bins, weights=herbin[iok])[0]
        woodgran = np.histogram2d(LAok, LOok, bins=bins, weights=woodin[iok])[0]
        defogran = np.histogram2d(LAok, LOok, bins=bins, weights=defoin[iok])[0]

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
    date[iok] = date[iok] / num[iok]

    # Recall values have a singleton time dim
    ds['batot'].values[0, :, :] = burn.astype(ds['batot'].dtype)
    ds['baherb'].values[0, :, :] = herb.astype(ds['baherb'].dtype)
    ds['bawood'].values[0, :, :] = wood.astype(ds['bawood'].dtype)
    ds['badefo'].values[0, :, :] = defo.astype(ds['badefo'].dtype)
    ds.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    # Assign day information if monthly output
    if monthly:
        ds = ds.assign(
            date=(
                ['time', 'lat', 'lon'],
                date[None, :, :].astype(datein.dtype),
                {'units': 'day of the year', 'long_name': 'Day of burning'},
            )
        )

    return ds


def build(dtbeg, dtend, **kwargs):
    """Build MODIS/VIIRS burned area"""

    print('===    ____ Burned Area')

    # Process arguments that are constant
    # ---
    kwnow = fillargs(dtbeg, **kwargs)

    product = kwnow['product']
    ver = kwnow['ver']
    restag = kwnow['restag']
    output = kwnow['output']

    doget = kwnow['get']
    doregrid = kwnow['regrid']
    doforce = kwnow['force']
    dotidy = kwnow['tidy']

    for year in range(dtbeg.year, dtend.year + 1):
        print(f'===    ________ {year}')

        # Output vars
        dirout = path.join(output, 'burn', f'{year}')
        headmon = path.join(dirout, f'{product}_v{ver}_burn_{restag}_monthly_')
        headday = path.join(dirout, f'{product}_v{ver}_burn_{restag}_daily_')

        # Build burned area
        # ---
        for nm in range(1, 13):
            # Skip if outside range
            if year == dtbeg.year and nm < dtbeg.month:
                continue
            elif year == dtend.year and dtend.month < nm:
                continue

            # Process arguments that can change
            # ---
            dtnow = datetime(year, nm, 1)
            kwnow = fillargs(dtnow, **kwargs)

            headburn = kwnow['headburn']

            print('===    ________ ' + dtnow.strftime('%Y-%m'))

            # Output vars
            fmon = headmon + dtnow.strftime('%Y%m') + '.' + FEXT

            # Download if requested or needed for regrid
            get4regrid = doregrid and (not path.isfile(fmon) or doforce)
            if get4regrid or doget:
                print('===    ____________ Downloading')
                get(dtnow, **kwnow)

            if doregrid:
                # Regrid monthlies
                print('===    ____________ Regridding')

                if path.isfile(fmon) and not doforce:
                    dsmon = xr.open_dataset(fmon)
                else:
                    dsmon = regrid(dtnow, monthly=True, **kwnow)
                    makedirs(dirout, exist_ok=True)
                    dsmon.to_netcdf(fmon, unlimited_dims=['time'])

                # Output dailies
                ndays = monthrange(year, nm)[1]
                for nd in range(1, ndays + 1):
                    dtnow = datetime(year, nm, nd)
                    kwnow = fillargs(dtnow, **kwargs)
                    fday = headday + dtnow.strftime('%Y%m%d') + '.' + FEXT
                    if not path.isfile(fday) or doforce:
                        # Hack to preserve v1 "bug" that averaged burn dates
                        if ver == '1':
                            ds = regrid(dtnow, **{**kwnow, 'regrid': False})

                            nd = (dtnow - datetime(year, 1, 1)).days + 1
                            iok = dsmon['date'].values == nd
                            ino = dsmon['date'].values != nd

                            for var in ['batot', 'baherb', 'bawood', 'badefo']:
                                ds[var].values[iok] = dsmon[var].values[iok]
                                ds[var].values[ino] = dsmon[var].values[ino] * 0
                            ds.attrs['input_files'] = dsmon.attrs['input_files']
                        else:
                            ds = regrid(dtnow, **kwnow)

                        ds.to_netcdf(fday, unlimited_dims=['time'])

                    # Finished?
                    if dtnow == dtend:
                        break

            # Slightly terrifying
            if dotidy:
                tidy(headburn, 3)

            # Finished?
            if dtnow == dtend:
                break

        # Slightly terrifying
        if dotidy and doregrid:
            tidy(kwnow['headcov'], 3)
            tidy(kwnow['headvcf'], 3)

    # Not sure why this is here of it's useful
    return ds
