'''
MiCASA vegetation index module
'''

from os import path
from glob import glob
from datetime import datetime, timedelta

import numpy as np
from modvir.patches import xarray as xr

from modvir.config import defaults, TIME0, TUNITS
from modvir.geometry import edges, centers, singrid

# Simple way to exclude most water, etc.
NDVIMIN = -0.3

def _regrid(dsout, dirin, mask=None):
    # Output grid
    nlat = dsout.sizes['lat']
    nlon = dsout.sizes['lon']
    late, lone = edges(nlat, nlon)

    # Output arrays
    num = np.zeros((nlat, nlon)) # Keeping in case we want Red and NIR outputs
    red = np.zeros((nlat, nlon))
    nir = np.zeros((nlat, nlon))

    # Read and regrid files in dirin
    # ---
    # MODIS
    XVAR = 'x'
    YVAR = 'y'
    VARPRE = 'Nadir_Reflectance_Band'
    QCFPRE = 'BRDF_Albedo_Band_Mandatory_Quality_Band'
    # Need mask_and_scale=False for zero-diff with rioxarray
    kwargs = {'engine':'rasterio', 'mask_and_scale':False}
    xyargs = {'engine':'rasterio', 'mask_and_scale':False}
    flist  = glob(path.join(dirin, '*.hdf'))
    if len(flist) == 0:
        # VIIRS
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
        flist  = glob(path.join(dirin, '*.h5'))
        if len(flist) == 0:
            raise EOFError('No files found in ' + dirin)

    fused = []
    for ff in flist:
        # Skip corrupted files in NRT mode, fail otherwise
        try:
            dsin = xr.open_dataset(ff, **kwargs).squeeze(drop=True)
            dsxy = xr.open_dataset(ff, **xyargs).squeeze(drop=True)
        except Exception as e:
            if ver == 'NRT':
                print(e)
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
    # Should this mask to NDVIMIN or 0? Looks like GIMMS masks to NDVIMIN
    if mask is not None:
        ndvi = (ndvi - NDVIMIN)*mask + NDVIMIN
#       ndvi = ndvi * mask

    # Recall values have a singleton time dim
    dsout['NDVI'].values[0,:,:] = ndvi.astype(dsout['NDVI'].dtype)

    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in fused])

    return dsout

def _ndvi2fpar_jojo(ndvi):
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

class VegInd(xr.Dataset):
    '''Vegetation index (NDVI/fPAR) class'''
    __slots__ = ()

    def __init__(self, dataset=None, time=defaults['date0'],
        nlat=defaults['nlat'], nlon=defaults['nlon']):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        tval = (time - TIME0).days
        tbvals = np.reshape([tval, tval + 1], (1, 2))
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

        tend = time + timedelta(days=1) - timedelta(microseconds=1)
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
            'time_bnds':time_bnds, 'NDVI':ndvi, 'fPAR':fpar,
        }, attrs=attrs)

    def ndvi2fpar(self, lctype):
        # Recall values have a singleton time dim
        fparxy = _ndvi2fpar_jojo(self['NDVI'].values[0,:,:])
        self['fPAR'].values[0,:,:] = fparxy
        return self

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)
