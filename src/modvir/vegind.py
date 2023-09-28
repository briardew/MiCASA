'''
MODIS/VIIRS vegetation index module
'''

# * Generalize to include VIIRS (will need to look for *.h5)
# * LAI?

from os import path
from glob import glob
from datetime import datetime

import numpy as np
import xarray as xr
import rioxarray as rxr

from modvir.config import defaults, NTYPE
from modvir.geometry import edges, centers, singrid

# Simple way to exclude most water, etc.
NDVIMIN = -0.3

# Read from yaml? Will want to estimate
# Has to match land cover type definitions
# Define as a dictionary?
NDVI02P = [0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330,
    0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330, 0.0330,
    0.0330]
NDVI98P = [0.7200, 0.8400, 0.8800, 0.8000, 0.8800, 0.8600, 0.7400, 0.7200,
    0.8000, 0.8000, 0.7200, 0.7800, 0.7800, 0.7800, 0.8200, 0.7200, 0.7200,
    0.7200]

# Los et al. (2000): https://doi.org/10.1175/1525-7541(2000)001<0183:AGYBLS>2.0.CO;2
fPMIN = 0.01
fPMAX = 0.95

def _regrid(dsout, dirin, mask=None):
    nlat = dsout.sizes['lat']
    nlon = dsout.sizes['lon']

    late, lone = edges(nlat, nlon)

    flist = glob(path.join(dirin, '*.hdf'))
    if len(flist) == 0:
        raise EOFError('no files to open')

    # Keeping num in case we want Red and NIR outputs
    num = np.zeros((nlat, nlon))
    red = np.zeros((nlat, nlon))
    nir = np.zeros((nlat, nlon))

    # Read and regrid (bin)
    # ---------------------
    for ff in flist:
        dsin = rxr.open_rasterio(ff).squeeze(drop=True)

        # Compute lat/lon mesh for MODIS sin grid
        LAin, LOin = singrid(dsin['y'].values, dsin['x'].values)

        # Read Red, NIR and QCs
        redin = dsin['Nadir_Reflectance_Band1'].values.T
        redqc = dsin['BRDF_Albedo_Band_Mandatory_Quality_Band1'].values.T
        nirin = dsin['Nadir_Reflectance_Band2'].values.T
        nirqc = dsin['BRDF_Albedo_Band_Mandatory_Quality_Band2'].values.T

        # Red and NIR have different QC
        # QC = 255 and val = 32767 are equiv but doing both out of paranoia
        iok = np.logical_and.reduce((redin != 32767, redqc != 255,
            nirin != 32767, nirqc != 255,
            NDVIMIN*(nirin + redin) <= nirin - redin))

        numgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone))[0]
        redgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=redin[iok])[0]
        nirgran = np.histogram2d(LAin[iok], LOin[iok], bins=(late,lone),
            weights=nirin[iok])[0]

        num = num + numgran
        red = red + redgran
        nir = nir + nirgran
    dsin.close()

    # Divide without complaining about NaNs
    with np.errstate(divide='ignore', invalid='ignore'):
        ndvi = (nir - red)/(nir + red)

    # Apply mask if provided
    if mask is not None:
    # Should this mask to NDVIMIN?
#       ndvi = (ndvi - NDVIMIN)*mask + NDVIMIN
    # Masking to 0 shows better agreement w/ GIMMS (worth revisiting)
        ndvi = ndvi * mask

    # Fill Dataset
    dsout['NDVI'].values = ndvi.astype(dsout['NDVI'].dtype)
    dsout.attrs['input_files'] = ', '.join([path.basename(ff) for ff in flist])

    return dsout

def _ndvi2fpar(ndvi, lctype):
    '''Convert NDVI to fPAR using Los et al. (2000) formulation'''

    def srfun(xx):
        return (1. + xx)/(1. - xx)

    fpar = np.zeros_like(ndvi)
    qt = np.zeros((NTYPE, 2))

    # Convert to using percent
    for nn in range(NTYPE):
        ime = lctype == nn

        ndlo = NDVI02P[nn]
        ndhi = NDVI98P[nn]
        srlo = srfun(ndlo)
        srhi = srfun(ndhi)

        sr = srfun(np.minimum(ndvi,ndhi))

        fpsr = (sr   - srlo)*(fPMAX - fPMIN)/(srhi - srlo) + fPMIN
        fpnd = (ndvi - ndlo)*(fPMAX - fPMIN)/(ndhi - ndlo) + fPMIN

        fpsr = np.maximum(fPMIN, np.minimum(fPMAX, fpsr))
        fpnd = np.maximum(fPMIN, np.minimum(fPMAX, fpnd))

        fpar[ime] = 0.5*(fpsr[ime] + fpnd[ime])

        # Add some capability to read/write quantiles
#       qt[nn,:] = np.nanquantile(ndvi[ime], [0.02, 0.98])

#   print(qt)
    fpar[np.isnan(fpar)] = 0.

    return fpar

class VegInd(xr.Dataset):
    '''Vegetation index (NDVI/fPAR) class'''
    __slots__ = ()

    def __init__(self, dataset=None, nlat=defaults['nlat'],
        nlon=defaults['nlon']):
        if dataset is not None:
           self = xr.Dataset.__init__(self, dataset)
           return

        lat, lon = centers(nlat, nlon)

        coords = {'lat':(['lat'], lat.astype(np.single),
                {'long_name':'latitude','units':'degrees north'}),
            'lon':(['lon'], lon.astype(np.single),
                {'long_name':'longitude','units':'degrees east'})}

        blank = np.nan * np.ones((nlat, nlon))

        dandvi = xr.DataArray(data=blank.astype(np.single),
            dims=['lat','lon'], coords=coords,
            attrs={'long_name':'Normalized difference vegetation index (NDVI)',
                'units':'%'})

        self = xr.Dataset.__init__(self,
            data_vars={'NDVI':dandvi},
            attrs={'Conventions':'CF-1.9',
                'title':'MODIS/VIIRS daily vegetation (NDVI/fPAR) data',
                'institution':'NASA GMAO Constituent Group',
                'contact':'Brad Weir <brad.weir@nasa.gov>',
                'input_files':''})

    def ndvi2fpar(self, lctype):
        fpar = _ndvi2fpar(self['NDVI'].values, lctype)

        return self.assign(fPAR=(['lat','lon'], fpar, {'units':'%',
            'long_name':'Fraction (absorbed) Photosynthetically Available ' +
            'Radiation (fPAR)'}))

    def regrid(self, *args, **kwargs):
        return _regrid(self, *args, **kwargs)

    def to_netcdf(self, *args, **kwargs):
        # Fill history with (close enough) timestamp
        self.attrs['history'] = 'Created on ' + datetime.now().isoformat()

        # Set _FillValue to None instead of NaN by default
        if 'encoding' not in kwargs:
            kwargs['encoding'] = {var:{'_FillValue':None}
                for var in self.variables}

        return super().to_netcdf(*args, **kwargs)
