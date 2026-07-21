"""
MODIS/VIIRS vegetation index module
"""

import sys
from os import path, makedirs
from glob import glob
from datetime import datetime, timedelta
from calendar import monthrange

import numpy as np
from modvir.patches import xarray as xr

from modvir import cover
from modvir.config import FEXT, TIME0, TUNITS, fillargs
from modvir.geometry import edges, centers, singrid
from modvir.utils import download, tidy

# Simple way to exclude most water, etc.
NDVIMIN = -0.3


def ndvi2fpar(ndvi):
    """Convert NDVI to fPAR using Joiner et al. (2018) formulation"""

    fpar = np.zeros_like(ndvi)

    #   Joiner et al. (2018) used N0 = 0.25, but I picked N0 = 0.15, not sure why
    N0 = 0.15
    N1 = 0.75

    iramp = np.logical_and(N0 < ndvi, ndvi <= N1)
    ifree = N1 < ndvi

    fpar[iramp] = (ndvi[iramp] - N0) / (N1 - N0) * N1
    fpar[ifree] = ndvi[ifree]

    fpar[np.isnan(fpar)] = 0.0

    return fpar


def get(dtnow, **kwargs):
    """Acquire MODIS/VIIRS vegetation index tiles"""

    kwnow = fillargs(dtnow, **kwargs)
    headveg = kwnow['headveg']
    dirveg = path.dirname(headveg)
    granveg = path.basename(headveg)

    # Check for local copies first (earthaccess is flaky)
    files = glob(headveg)
    if len(files) == 0 or kwnow['force']:
        files = download(granveg, dirveg, kwnow['force'])

    return files


def regrid(dtnow, mask=None, monthly=False, **kwargs):
    """Regrid MODIS/VIIRS vegetation indicies"""

    # Process arguments
    # ---
    kwnow = fillargs(dtnow, **kwargs)

    nlat = kwnow['nlat']
    nlon = kwnow['nlon']
    prod = kwnow['prod']
    ver = kwnow['ver']
    # Split full version (###-XYZ) into number (###) and domain (XYZ)
    vernum, _, domain = ver.partition('-')

    if not monthly:
        ndays = 1
    else:
        ndays = monthrange(dtnow.year, dtnow.month)[1]

    # Define coordinates
    # ---
    tnow = (dtnow - TIME0).days
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

    qclong = 'Quality control variable (greater = better)'
    qc = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': qclong, 'units': '1'},
    )

    ndvilong = 'Normalized difference vegetation index (NDVI)'
    ndvi = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': ndvilong, 'units': '1'},
    )

    fparlong = 'Fraction absorbed Photosynthetically Available Radiation (fPAR)'
    fpar = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time', 'lat', 'lon'],
        coords=coords,
        attrs={'long_name': fparlong, 'units': '1'},
    )

    # Define attributes
    # ---
    reslong = (
        f'{round(late[1] - late[0], 3)} degree x '
        + f'{round(lone[1] - lone[0], 3)} degree'
    )
    if not monthly:
        shortname = f'{prod.upper()}_VEGIND_D'
        longname = f'{prod} Daily Vegetation Indices {reslong}'
    else:
        shortname = f'{prod.upper()}_VEGIND_M'
        longname = f'{prod} Monthly Vegetation Indices {reslong}'
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
        data_vars={'time_bnds': time_bnds, 'QC': qc, 'NDVI': ndvi, 'fPAR': fpar},
        attrs=attrs,
    )

    # Just give the empty structure if not regridding or monthly mean
    if not kwnow['regrid'] or monthly:
        return ds

    # Read and regrid files
    # ---
    files = get(dtnow, **kwnow)

    num = np.zeros((nlat, nlon))
    qcw = np.zeros((nlat, nlon))
    red = np.zeros((nlat, nlon))
    nir = np.zeros((nlat, nlon))

    if files[0][-3:] == 'hdf':
        # MODIS
        # ---
        XVAR = 'x'
        YVAR = 'y'
        VARPRE = 'Nadir_Reflectance_Band'
        QCFPRE = 'BRDF_Albedo_Band_Mandatory_Quality_Band'
        # Need mask_and_scale=False for zero-diff with rioxarray
        inargs = {'engine': 'rasterio', 'mask_and_scale': False}
        xyargs = {'engine': 'rasterio', 'mask_and_scale': False}
    elif files[0][-2:] == 'h5':
        # VIIRS
        # ---
        XVAR = 'XDim'
        YVAR = 'YDim'
        VARPRE = 'Nadir_Reflectance_I'
        QCFPRE = 'BRDF_Albedo_Band_Mandatory_Quality_I'
        # Need mask_and_scale=False for zero-diff with rioxarray
        # Here again for compatibility with HDF-EOS
        inargs = {
            'engine': 'h5netcdf',
            'phony_dims': 'sort',
            'group': '/HDFEOS/GRIDS/VIIRS_Grid_BRDF/Data Fields',
            'mask_and_scale': False,
        }
        xyargs = {
            'engine': 'h5netcdf',
            'phony_dims': 'sort',
            'group': '/HDFEOS/GRIDS/VIIRS_Grid_BRDF',
            'mask_and_scale': False,
        }
    else:
        raise ValueError('Unsupported file format ' + files[0])

    fused = []
    for ff in files:
        # Skip corrupted files in NRT mode, fail otherwise
        try:
            dsin = xr.open_dataset(ff, **inargs).squeeze(drop=True)
            dsxy = xr.open_dataset(ff, **xyargs).squeeze(drop=True)
        except Exception as e:
            if ver == 'NRT':
                print(f'{type(e).__name__}: {e}', file=sys.stderr)
                continue
            else:
                raise (e)

        fused = fused + [ff]

        # Read Red & NIR QC and values
        redqc = dsin[QCFPRE + '1'].values.T
        nirqc = dsin[QCFPRE + '2'].values.T
        redin = dsin[VARPRE + '1'].values.T
        nirin = dsin[VARPRE + '2'].values.T
        if ver != '1':
            # qc = 0 => qcw = 2; qc = 1 => qcw = 1
            qcwin = 2 - 0.5 * (redqc + nirqc)
        else:
            # Hack to preserve v1 approach
            qcwin = np.ones_like(redqc + nirqc)

        # Red and NIR can have different QC
        # QC = 255 and val = 32767 are equiv, but sometimes val = -32767
        # QC = 0 is too strict over cloudy regions, e.g., Amazon
        # QC = 1 is an over-agressive fill we must live with
        iok = np.logical_and.reduce(
            (
                redqc != 255,
                nirqc != 255,
                abs(redin) != 32767,
                abs(nirin) != 32767,
                NDVIMIN * (nirin + redin) <= nirin - redin,
            )
        )

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsxy[YVAR].values, dsxy[XVAR].values)

        LAok = LAin[iok]
        LOok = LOin[iok]
        bins = (late, lone)

        # NB: red and nir are kept unnormalized until after NDVI is computed
        wredin = redin * qcwin
        wnirin = nirin * qcwin

        numgran = np.histogram2d(LAok, LOok, bins=bins)[0]
        qcwgran = np.histogram2d(LAok, LOok, bins=bins, weights=qcwin[iok])[0]
        redgran = np.histogram2d(LAok, LOok, bins=bins, weights=wredin[iok])[0]
        nirgran = np.histogram2d(LAok, LOok, bins=bins, weights=wnirin[iok])[0]

        num = num + numgran
        qcw = qcw + qcwgran
        red = red + redgran
        nir = nir + nirgran

        dsin.close()
        dsxy.close()

    # 1deg = 120km => 500m = 1/240deg; recall range of qcw is [0, 2]
    area = (np.max(late) - np.min(late)) * (np.max(lone) - np.min(lone))
    qc = 1 - 0.5 * qcw * nlat * nlon / (240 * 240 * area)

    # Divide without complaining about NaNs
    with np.errstate(divide='ignore', invalid='ignore'):
        ndvi = (nir - red) / (nir + red)
        # Now normalize red and nir
        red = red / qcw
        nir = nir / qcw

    # Apply mask if provided
    if mask is not None:
        ndvi = (ndvi - NDVIMIN) * mask + NDVIMIN
    fpar = ndvi2fpar(ndvi)

    # Recall values have a singleton time dim
    # Type cast is to prevent xarray from casting :(
    ds['QC'].values[0, :, :] = qc.astype(ds['QC'].dtype)
    ds['NDVI'].values[0, :, :] = ndvi.astype(ds['NDVI'].dtype)
    ds['fPAR'].values[0, :, :] = fpar.astype(ds['fPAR'].dtype)

    ds.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    return ds


def build(dtbeg, dtend, **kwargs):
    """Build MODIS/VIIRS vegetation indices"""

    print('===    ____ Vegetation Indicies')

    # Process arguments that are constant
    # ---
    kwnow = fillargs(dtbeg, **kwargs)

    prod = kwnow['prod']
    ver = kwnow['ver']
    restag = kwnow['restag']
    output = kwnow['output']

    dofill = kwnow['fill']
    doget = kwnow['get']
    doregrid = kwnow['regrid']
    doforce = kwnow['force']
    dotidy = kwnow['tidy']

    ds = None
    dsold = None
    for year in range(dtbeg.year, dtend.year + 1):
        print(f'===    ________ {year}')

        # Output vars
        dirpre = path.join(output, 'vegpre', f'{year}')
        headpre = path.join(dirpre, f'{prod}_v{ver}_vegpre_{restag}_daily_')
        dirout = path.join(output, 'vegind', f'{year}')
        headout = path.join(dirout, f'{prod}_v{ver}_vegind_{restag}_daily_')

        # Compute vegetation mask
        # ---
        dtnow = datetime(year, 1, 1)
        kwnow = fillargs(dtnow, **kwargs)
        if kwnow['regrid'] or kwnow['fill']:
            print('')
            # Build/read land cover
            kwcov = kwnow
            kwcov['regrid'] = True
            dscov = cover.build(dtnow, dtnow, **kwcov)

            ftype = dscov['ftype'].values
            # Remove singleton time dim (and support older versions without)
            if len(ftype.shape) == 4:
                ftype = ftype[0, :, :, :]
            # Will need to make this a function in the class (remember
            # 0 indexing): Unclassified (17), water bodies (16), snow/ice (14)
            # Not excluding wetlands (closer to GIMMS)
            mask = 1.0 - (ftype[17, :, :] + ftype[16, :, :] + ftype[14, :, :])

            dscov.close()
            print('')

        # Build daily vegetation indices
        # ---
        dtcap = min(datetime(year, 12, 31), dtend)
        ndays = (dtcap - dtbeg).days + 1
        for nd in range(ndays):
            dtnow = dtbeg + timedelta(nd)

            print('===    ________ ' + dtnow.strftime('%Y-%m-%d'))

            # Process arguments that can change
            # ---
            kwnow = fillargs(dtnow, **kwargs)
            headveg = kwnow['headveg']

            dateout = dtnow.strftime('%Y%m%d')
            fout = headout + dateout + '.' + FEXT
            fpre = headpre + dateout + '.' + FEXT

            # Download if requested or needed for regrid
            # ---
            get4regrid = doregrid and (not path.isfile(fpre) or doforce)
            if get4regrid or doget:
                print('===    ____________ Downloading')
                get(dtnow, **kwnow)

            # Read or regrid preliminary file
            # ---
            if doregrid:
                print('===    ____________ Regridding')
                if path.isfile(fpre) and not doforce:
                    ds = xr.open_dataset(fpre)
                else:
                    try:
                        ds = regrid(dtnow, mask=mask, **kwnow)
                    except EOFError:
                        print('No files to process, proceeding ...', file=sys.stderr)
                    else:
                        makedirs(dirpre, exist_ok=True)
                        ds.to_netcdf(fpre, unlimited_dims=['time'])

            # Fill and compute fPAR
            # ---
            if dofill:
                print('===    ____________ Filling')
                if path.isfile(fout) and not doforce:
                    ds = xr.open_dataset(fout)
                else:
                    if dsold is not None:
                        ndvi = ds['NDVI'].values
                        ndvi0 = dsold['NDVI'].values
                        # Hack to support 2D arrays from earlier versions
                        if len(ndvi0.shape) == 2:
                            ndvi0 = ndvi0[None, :]

                        iold = ~np.isnan(ndvi0) & np.isnan(ndvi)
                        inew = ~np.isnan(ndvi0) & ~np.isnan(ndvi)
                        if ver != '1':
                            wold = ds['QC'].values
                        else:
                            # Hack to preserve v1 approach
                            wold = np.zeros_like(ds['QC'].values)

                        ndvi1 = (1 - wold) * ndvi + wold * ndvi0
                        ndvi[iold] = ndvi0[iold]
                        ndvi[inew] = ndvi1[inew]
                        ds['NDVI'].values = ndvi
                        ds['fPAR'].values = ndvi2fpar(ndvi)

                    makedirs(dirout, exist_ok=True)
                    ds.to_netcdf(fout, unlimited_dims=['time'])
                dsold = ds.copy(deep=True)

            # Clean up files (slightly terrifying)
            if dotidy:
                tidy(headveg, 3)

        # Compute monthly means
        # ---
        if dofill:
            headmon = path.join(dirout, f'{prod}_v{ver}_vegind_{restag}_monthly_')
            for mon in range(1, 13):
                datemon = f'{year:04}{mon:02}'
                fmon = headmon + datemon + '.' + FEXT
                # Skip if file exists and not overwriting
                if path.isfile(fmon) and not doforce:
                    continue

                flist = glob(headout + datemon + '??.' + FEXT)
                ndays = monthrange(year, mon)[1]
                # Skip if days don't cover month
                if len(flist) != ndays:
                    continue

                print('===    ________ ' + f'{year:04}-{mon:02}')
                print('===    ____________ Averaging')

                # I try not to do this (dtmon & dsmon), but alas
                dtmon = datetime(year, mon, 1)
                dsmon = regrid(dtmon, mask=mask, monthly=True, **kwnow)
                with xr.open_mfdataset(flist) as dsin:
                    # Different versions of xarray return different things for
                    # `Dataset.mean`. Better to just do the average and replace arrays
                    # in an exisiting dataset
                    dsavg = dsin.mean(dim='time').expand_dims('time')
                    for var in dsavg.data_vars:
                        dsmon[var].values = dsavg[var].values
                    dsmon.to_netcdf(fmon, unlimited_dims=['time'])

    if dsold is not None:
        dsold.close()

    return ds
