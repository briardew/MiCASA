# * Figure out how to extend land cover and VCF
# Seems like we need a switch to do NRT or not. We want to know if
# persistence has been used or not
# * Can we back off the filling for NDVI? Looks like too much over
# CONUS, but more stringent options have been untenable in tropics
# * Can't always do download for NBAR. Would just want to link NRT
# product

import sys
import numpy as np
import xarray as xr

from os import path
from subprocess import check_call
from datetime import datetime, timedelta
from calendar import monthrange

from modvir.config import defaults, check_args, check_cols
from modvir.config import BEGYEARCOV, ENDYEARCOV, BEGYEARVCF, ENDYEARVCF
from modvir.utils import download
from modvir.cover import Cover
from modvir.vegind import VegInd
from modvir.burn import Burn

def cover(data=defaults['data'], date0=defaults['date0'],
    dateF=defaults['dateF'], nlat=defaults['nlat'], nlon=defaults['nlon'],
    **kwargs):
    '''Build (re)gridded MODIS/VIIRS land cover type dataset'''

    # Check and read arguments
    kwargs = check_args(date0, dateF, **kwargs)

    # Initialize
    cc = Cover(nlat=nlat, nlon=nlon)
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    year0 = max(date0.year, BEGYEARCOV)
    yearF = min(dateF.year, ENDYEARCOV)

    # Loop over years
    for year in range(year0, yearF+1):
        jdnow = datetime(year, 1, 1)

        # Year-specific strings
        syear = str(year)
        dircov = path.join(data, 'cover')
        fcov = path.join(dircov, 'modvir_cover.' + restag + '.yearly.' +
            syear + '.nc')

        # Download?
        colcov = check_cols(jdnow, **kwargs)['colcov']
        dateget = jdnow.strftime('%Y.%m.%d')
        dirget = path.join(data, colcov, syear, '001')
        if kwargs['get']: download(colcov, dateget, dirget)

        if not kwargs['regrid']: continue

        # Read or regrid
        if path.isfile(fcov) and not kwargs['repro']:
            cc = Cover(xr.open_dataset(fcov))
        else:
            pout = check_call(['mkdir', '-p', dircov])
            cc = cc.regrid(dirget)
            cc.to_netcdf(fcov)

            # Slightly terrifying
            if kwargs['get'] and kwargs['rmcol']:
                pout = check_call(['rm', '-rf', dirget])

    return cc

def vegind(data=defaults['data'], date0=defaults['date0'],
    dateF=defaults['dateF'], nlat=defaults['nlat'], nlon=defaults['nlon'],
    **kwargs):
    '''Build (re)gridded MODIS/VIIRS vegetation index dataset'''

    # Check and read arguments
    kwargs = check_args(date0, dateF, **kwargs)

    # Initialize
    vv = VegInd(nlat=nlat, nlon=nlon)
    if kwargs['fill']:
        vv.attrs['title'] += ': Final, filled with persistence'
    else:
        vv.attrs['title'] += ': Preliminary, no persistence'
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    # Loop over years
    for year in range(date0.year, dateF.year+1):
        # Compute vegetation mask
        # -----------------------
        if kwargs['regrid'] or kwargs['fill']:
            # Build/read yearly land cover type
            cc = cover(**kwargs)

            percent = cc['percent'].values
            # Will need to make this a function in the class (remember
            # 0 indexing): Unclassified (17), water bodies (16), snow/ice (14),
            # wetlands (10)
#           mask = 1. - (percent[17,:,:] + percent[16,:,:] + percent[14,:,:] +
#               0.5*percent[10,:,:])
            # Not using wetlands even though it makes sense (closer to GIMMS)
            mask = 1. - (percent[17,:,:] + percent[16,:,:] + percent[14,:,:])

        # Build/read daily vegetation indices
        # -----------------------------------
        # Year-specific strings
        syear = str(year)
        dirpre  = path.join(data, 'vegpre', syear)
        headpre = path.join(dirpre, 'modvir_vegpre.' + restag + '.daily.')
        dirveg  = path.join(data, 'vegind', syear)
        headveg = path.join(dirveg, 'modvir_vegind.' + restag + '.daily.')

        # Time period
        jday0 = max(datetime(year, 1, 1), date0)
        jdayF = min(datetime(year,12,31), dateF)
        ndays = (jdayF - jday0).days + 1
        for nd in range(ndays):
            # Day-specific strings
            jdnow = jday0 + timedelta(nd)
            dateget = jdnow.strftime('%Y.%m.%d')
            jdayget = jdnow.strftime('%j')
            dateveg = jdnow.strftime('%Y%m%d')

            colveg = check_cols(jdnow, **kwargs)['colveg']
            dirget = path.join(data, colveg, syear, jdayget)
            fveg = headveg + dateveg + '.nc'
            fpre = headpre + dateveg + '.nc'

            # Download
            if kwargs['get']: download(colveg, dateget, dirget)

            if not kwargs['regrid'] and not kwargs['fill']: continue

            vvold = vv.copy(deep=True)

            if kwargs['regrid']:
                if path.isfile(fpre) and not kwargs['repro']:
                    vv = VegInd(xr.open_dataset(fpre))
                else:
                    try:
                        vv = vv.regrid(dirget, mask=mask)
                    except EOFError as message:
                        sys.stderr.write('\n*** WARNING **** %s on %s' %
                            (message, jdnow.strftime('%Y-%m-%d')))
                        sys.stderr.write('\nNo output, proceeding ...\n')
                    else:
                        pout = check_call(['mkdir', '-p', dirpre])
                        vv.to_netcdf(fpre)

            # Read or regrid filled file
            if kwargs['fill']:
                if path.isfile(fveg) and not kwargs['repro']:
                    vv = VegInd(xr.open_dataset(fveg))
                else:
                    # Fill with persistence
                    inan = np.logical_and(np.isnan(vv['NDVI'].values),
                        ~np.isnan(vvold['NDVI'].values))
                    vv['NDVI'].values[inan] = vvold['NDVI'].values[inan]

                    # Compute fPAR ala Los et al. (2000)
                    vv = vv.ndvi2fpar(cc['mode'].values)

                    pout = check_call(['mkdir', '-p', dirveg])
                    vv.to_netcdf(fveg)

            # Slightly terrifying
            if kwargs['get'] and kwargs['rmcol']:
                pout = check_call(['rm', '-rf', dirget])

    if kwargs['regrid'] or kwargs['fill']: cc.close()
    return vv

def burn(data=defaults['data'], date0=defaults['date0'],
    dateF=defaults['dateF'], nlat=defaults['nlat'], nlon=defaults['nlon'],
    **kwargs):
    '''Build (re)gridded MODIS/VIIRS burned area dataset'''

    # Check and read arguments
    kwargs = check_args(date0, dateF, **kwargs)

    # Initialize
    bb = Burn(nlat=nlat, nlon=nlon)
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    # Loop over years
    for year in range(date0.year, dateF.year+1):
        syear = str(year)
        jdyear = datetime(year, 1, 1)

        # Read and fill collections
        kwargs = check_cols(jdyear, **kwargs)
        colcov = kwargs['colcov']
        colvcf = kwargs['colvcf']

        # Download land cover
        yearcov = min(max(year, BEGYEARVCF), ENDYEARVCF)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        dircov  = path.join(data, colcov, syear, '001')
        headcov = path.join(data, colcov, syear, '001',
            colcov[:-4] + '.A' + syear + '001.')
        if kwargs['regrid'] and kwargs['get']:
            download(colcov, datecov, dircov)

        # Build burned area
        # =================
        dirout = path.join(data, 'burn', syear)
        headmon = path.join(dirout, 'modvir_burn.' + restag + '.monthly.')
        headday = path.join(dirout, 'modvir_burn.' + restag + '.daily.')

        for nm in range(1,13):
            jdmonth = datetime(year, nm, 1)
            dateget = jdmonth.strftime('%Y.%m.%d')
            jdayget = jdmonth.strftime('%j')

            # Download and/or regrid burned area
            # ----------------------------------
            colburn = check_cols(jdmonth, **kwargs)['colburn']
            dirget   = path.join(data, colburn, syear, jdayget)
            headburn = path.join(data, colburn, syear, jdayget,
                colburn[:-4] + '.A' + syear + jdayget + '.')
            if kwargs['get']: download(colburn, dateget, dirget)

            if not kwargs['regrid']: continue

            # Download VCF
            # ------------
            yearvcf = min(max(year - (nm < 3)*1, BEGYEARVCF), ENDYEARVCF)
            datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
            ystrvcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y')
            dirvcf  = path.join(data, colvcf, ystrvcf, '065')
            headvcf = path.join(data, colvcf, ystrvcf, '065',
                colvcf[:-4] + '.A' + ystrvcf + '065.')
            if kwargs['get']: download(colvcf, datevcf, dirvcf)

            # Read or regrid monthlies
            fmon = headmon + jdmonth.strftime('%Y%m') + '.nc'
            if path.isfile(fmon) and not kwargs['repro']:
                bb = Burn(xr.open_dataset(fmon))
            else:
                pout = check_call(['mkdir', '-p', dirout])
                bb = bb.regrid(dirget, headburn, headcov, headvcf)
                bb.to_netcdf(fmon)

            # Output dailies
            ndays = monthrange(year, nm)[1]
            for nd in range(1,ndays+1):
                jdnow = datetime(year, nm, nd)
                fday  = headday + jdnow.strftime('%Y%m%d') + '.nc'
                if not path.isfile(fday) or kwargs['repro']: 
                    bbnow = bb.daysel((jdnow - jdyear).days + 1)
                    bbnow.to_netcdf(fday)

                # Finished?
                if jdnow == dateF:
                    if kwargs['get'] and kwargs['rmcol']:
                        # Slightly terrifying
                        pout = check_call(['rm', '-rf', dirget])
                        pout = check_call(['rm', '-rf', dircov])
                        pout = check_call(['rm', '-rf', dirvcf])
                    return bb

            # Slightly terrifying
            if kwargs['get'] and kwargs['rmcol']:
                pout = check_call(['rm', '-rf', dirget])
                pout = check_call(['rm', '-rf', dirvcf])

        # Slightly terrifying
        if kwargs['get'] and kwargs['rmcol']:
            pout = check_call(['rm', '-rf', dircov])

    return bb
