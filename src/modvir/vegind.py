'''
MODIS/VIIRS vegetation index module
'''

import sys
from os import path, makedirs, remove, rmdir
from glob import glob
from datetime import datetime, timedelta

import numpy as np
from modvir.patches import xarray as xr

from modvir import cover
from modvir.config import FEXT, TIME0, TUNITS, fillargs
from modvir.geometry import edges, centers, singrid
from modvir.utils import download, tidy

# Simple way to exclude most water, etc.
NDVIMIN = -0.3

def ndvi2fpar(ndvi):
    '''Convert NDVI to fPAR using Joiner et al. (2018) formulation'''

    fpar = np.zeros_like(ndvi)

#   Joiner et al. (2018) used N0 = 0.25, but I picked N0 = 0.15, not sure why
    N0 = 0.15
    N1 = 0.75

    iramp = np.logical_and(N0 < ndvi, ndvi <= N1)
    ifree = N1 < ndvi

    fpar[iramp] = (ndvi[iramp] - N0)/(N1 - N0)*N1
    fpar[ifree] =  ndvi[ifree]

    fpar[np.isnan(fpar)] = 0.

    return fpar

def get(dtval, **kwargs):
    '''Acquire MODIS/VIIRS vegetation index tiles'''

    kwargs = fillargs(dtval, **kwargs)
    colveg = kwargs['colveg']
    headveg = kwargs['headveg']

    files = download(dtval, colveg, path.dirname(headveg), kwargs['force'])

    if len(files) == 0:
        raise EOFError(f'No granules found for {colveg} on {dtval:%Y-%m-%d}')

    return files

def regrid(dtval, mask=None, **kwargs):
    '''Regrid MODIS/VIIRS vegetation indicies'''

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
    tbvals = np.reshape([tval, tval + 1], (1, 2))
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
    ndvi = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time','lat','lon'], coords=coords,
        attrs={'long_name':'Normalized difference vegetation index (NDVI)',
            'units':'1'},
    )
    fpar = xr.DataArray(
        data=nansxyt.astype(np.single),
        dims=['time','lat','lon'], coords=coords,
        attrs={'long_name':('Fraction absorbed Photosynthetically ' + 
            'Available Radiation (fPAR)'), 'units':'1'},
    )

    # Define attributes
    # ---
    shortname = 'MICASA_VEGIND_D'
    longname = ('MiCASA Daily Vegetation Indices ' +
        f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    dtend = dtval + timedelta(days=1) - timedelta(microseconds=1)

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
        'time_bnds':time_bnds, 'NDVI':ndvi, 'fPAR':fpar,
    }, attrs=attrs)

    # Just give the empty structure if not regridding
    if not kwargs['regrid']: return ds

    # Read and regrid files
    # ---
    files = get(dtval, **kwargs)

    num = np.zeros((nlat, nlon)) # Keeping in case we want Red and NIR outputs
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
        kwargs = {'engine':'rasterio', 'mask_and_scale':False}
        xyargs = {'engine':'rasterio', 'mask_and_scale':False}
    elif files[0][-2:] == 'h5':
        # VIIRS
        # ---
        XVAR = 'XDim'
        YVAR = 'YDim'
        VARPRE = 'Nadir_Reflectance_I'
        QCFPRE = 'BRDF_Albedo_Band_Mandatory_Quality_I'
        # Need mask_and_scale=False for zero-diff with rioxarray
        # Here again for compatibility with HDF-EOS
        kwargs = {'engine':'h5netcdf', 'phony_dims':'sort',
            'group':'/HDFEOS/GRIDS/VIIRS_Grid_BRDF/Data Fields',
            'mask_and_scale':False}
        xyargs = {'engine':'h5netcdf', 'phony_dims':'sort',
            'group':'/HDFEOS/GRIDS/VIIRS_Grid_BRDF',
            'mask_and_scale':False}
    else:
        raise ValueError('Unsupported file format ' + files[0])

    fused = []
    for ff in files:
        # Skip corrupted files in NRT mode, fail otherwise
        try:
            dsin = xr.open_dataset(ff, **kwargs).squeeze(drop=True)
            dsxy = xr.open_dataset(ff, **xyargs).squeeze(drop=True)
        except Exception as e:
            if ver == 'NRT':
                print(f'{type(e).__name__}: {e}', file=sys.stderr)
                continue
            else:
                raise(e)

        fused = fused + [ff]

        # Read Red, NIR and QCs
        redin = dsin[VARPRE+'1'].values.T
        redqc = dsin[QCFPRE+'1'].values.T
        nirin = dsin[VARPRE+'2'].values.T
        nirqc = dsin[QCFPRE+'2'].values.T

        # Red and NIR can have different QC
        # QC = 255 and val = 32767 are equiv, but sometimes val = -32767
        # QC = 0 is too strict over cloudy regions, e.g., Amazon
        # QC = 1 is an over-agressive fill we must live with
        iok = np.logical_and.reduce((abs(redin) != 32767, redqc != 255,
            abs(nirin) != 32767, nirqc != 255,
            NDVIMIN*(nirin + redin) <= nirin - redin))

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsxy[YVAR].values, dsxy[XVAR].values)

        numgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone))[0]
        redgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=redin[iok])[0]
        nirgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=nirin[iok])[0]

        num = num + numgran
        red = red + redgran
        nir = nir + nirgran

        dsin.close()
        dsxy.close()

    # Divide without complaining about NaNs
    with np.errstate(divide='ignore', invalid='ignore'):
        ndvi = (nir - red)/(nir + red)

    # Apply mask if provided
    if mask is not None:
        ndvi = (ndvi - NDVIMIN)*mask + NDVIMIN
    fpar = ndvi2fpar(ndvi)

    # Recall values have a singleton time dim
    # Type cast is to prevent xarray from casting :(
    ds['NDVI'].values[0,:,:] = ndvi.astype(ds['NDVI'].dtype)
    ds['fPAR'].values[0,:,:] = fpar.astype(ds['fPAR'].dtype)

    ds.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    return ds

def build(dtbeg, dtend, **kwargs):
    '''Build MODIS/VIIRS vegetation indices'''

    print('===    ____ Vegetation Indicies')

    dsold = None
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
        dirpre  = path.join(output, 'vegpre', f'{year}')
        headpre = path.join(dirpre, f'MiCASA_v{ver}_vegpre_{domtag}_daily_')
        dirout  = path.join(output, 'vegind', f'{year}')
        headout = path.join(dirout, f'MiCASA_v{ver}_vegind_{domtag}_daily_')

        # Compute vegetation mask
        # ---
        if kwyear['regrid'] or kwyear['fill']:
            # Build/read land cover
            kwcov = kwyear
            kwcov['regrid'] = True
            dscov = cover.build(dtyear, dtyear, **kwcov)
            print('')

            # Recall values have a singleton time dim
            ftype = dscov['ftype'].values[0,:,:,:]
            # Will need to make this a function in the class (remember
            # 0 indexing): Unclassified (17), water bodies (16), snow/ice (14),
            # wetlands (10)
#           mask = 1. - (ftype[17,:,:] + ftype[16,:,:] + ftype[14,:,:] +
#               0.5*ftype[10,:,:])
            # Not using wetlands even though it makes sense (closer to GIMMS)
            mask = 1. - (ftype[17,:,:] + ftype[16,:,:] + ftype[14,:,:])

            dscov.close()

        # Build daily vegetation indices
        # ---
        dtbeg = max(datetime(year, 1, 1), dtbeg)
        dtend = min(datetime(year,12,31), dtend)
        ndays = (dtend - dtbeg).days + 1
        for nd in range(ndays):
            dtnow = dtbeg + timedelta(nd)

            print('===    ________ ' + dtnow.strftime('%Y-%m-%d'))

            # Process arguments
            # ---
            kwnow = fillargs(dtnow, **kwargs)
            headveg = kwnow['headveg']

            doget = kwnow['get']
            doregrid = kwnow['regrid']
            dofill = kwnow['fill']
            doforce = kwnow['force']
            dotidy = kwnow['tidy']

            dateout = dtnow.strftime('%Y%m%d')
            fout = headout + dateout + '.' + FEXT
            fpre = headpre + dateout + '.' + FEXT

            # Download if requested or needed for regrid
            get4regrid = doregrid and (not path.isfile(fpre) or doforce)
            if get4regrid or doget:
                print('===    ____________ Downloading')
                get(dtnow, **kwnow)

            # Read or regrid preliminary file
            if doregrid:
                print('===    ____________ Regridding')
                if path.isfile(fpre) and not doforce:
                    ds = xr.open_dataset(fpre)
                else:
                    try:
                        ds = regrid(dtnow, mask=mask, **kwnow)
                    except EOFError as message:
                        print('No files to process, proceeding ...',
                            file=sys.stderr)
                    else:
                        makedirs(dirpre, exist_ok=True)
                        ds.to_netcdf(fpre, unlimited_dims=['time'])

            # Read or regrid filled file
            if dofill:
                print('===    ____________ Filling')
                if path.isfile(fout) and not doforce:
                    ds = xr.open_dataset(fout)
                else:
                    # Fill with persistence and compute fPAR
                    if dsold is not None:
                        inan = np.logical_and(np.isnan(ds['NDVI'].values),
                            ~np.isnan(dsold['NDVI'].values))
                        ds['NDVI'].values[inan] = dsold['NDVI'].values[inan]
                        ds['fPAR'].values = ndvi2fpar(ds['NDVI'].values)

                    makedirs(dirout, exist_ok=True)
                    ds.to_netcdf(fout, unlimited_dims=['time'])
                dsold = ds.copy(deep=True)

            # Slightly terrifying
            if dotidy: tidy(headveg)

    if dsold is not None: dsold.close()

    return ds
