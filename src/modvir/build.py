# * Can we back off the filling for NDVI? Looks like too much over
#   CONUS, but more stringent options have been untenable in tropics
# * Burned area tries to download entire year, only exits if
#   regridding (***FIXME***)

import sys
import numpy as np
import xarray as xr

from os import path
from subprocess import check_call
from datetime import datetime, timedelta
from calendar import monthrange

from modvir.config import (defaults, check_args, check_cols,
    YMAXCOV, YMAXVCF)
from modvir.utils  import download
from modvir.cover  import Cover
from modvir.vegind import VegInd
from modvir.burn   import Burn

def cover(**kwargs):
    '''Build (re)gridded MODIS/VIIRS land cover dataset'''

    print('')
    print('===    ____ Land Cover                   ===')

    # Check and read arguments
    kwargs = check_args(**kwargs)

    data  = kwargs['data']
    date0 = kwargs['date0']
    dateF = kwargs['dateF']
    nlat  = kwargs['nlat']
    nlon  = kwargs['nlon']

    # Use 2001 land cover for 2000
    date0 = max(date0, datetime(2001, 1, 1))
    dateF = max(dateF, datetime(2001, 1, 1))

    # Initialize
    cc = Cover(nlat=nlat, nlon=nlon)
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    for year in range(date0.year, dateF.year+1):
        jdnow = datetime(year, 1, 1)

        # Year-specific strings
        syear  = str(year)
        dirout = path.join(data, 'cover')
        fout   = path.join(dirout, 'modvir_cover.' + restag + '.yearly.' +
            syear + '.nc')

        print('===    ________ ' + syear + '                     ===')

        # Download land cover
        colcov  = check_cols(jdnow, **kwargs)['colcov']
        yearcov = min(year, YMAXCOV)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        ystrcov = datetime(yearcov, 1, 1).strftime('%Y')
        dircov  = path.join(data, colcov, ystrcov, '001')
        headcov = path.join(data, colcov, ystrcov, '001',
            colcov[:-4] + '.A' + ystrcov + '001.')

        if kwargs['get']:
            print('===    ____________ Downloading          ===')
            download(colcov, datecov, dircov)

        # Download VCF
        colvcf  = check_cols(jdnow, **kwargs)['colvcf']
        yearvcf = min(year, YMAXVCF)
        datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
        ystrvcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y')
        dirvcf  = path.join(data, colvcf, ystrvcf, '065')
        headvcf = path.join(data, colvcf, ystrvcf, '065',
            colvcf[:-4] + '.A' + ystrvcf + '065.')

        if kwargs['get']:
            download(colvcf, datevcf, dirvcf)

        # Read or regrid
        if not kwargs['regrid']: continue

        print('===    ____________ Regridding           ===')
        if path.isfile(fout) and not kwargs['repro']:
            cc = Cover(xr.open_dataset(fout))
        else:
            pout = check_call(['mkdir', '-p', dirout])
            cc = cc.regrid(dircov, headcov, headvcf)
            cc.to_netcdf(fout)

            # Slightly terrifying
            if kwargs['get'] and kwargs['tidy']:
                pout = check_call(['rm', '-rf', dircov])

    return cc

def vegind(**kwargs):
    '''Build (re)gridded MODIS/VIIRS vegetation indices dataset'''

    print('')
    print('===    ____ Vegetation Indicies          ===')

    # Check and read arguments
    kwargs = check_args(**kwargs)

    data  = kwargs['data']
    date0 = kwargs['date0']
    dateF = kwargs['dateF']
    nlat  = kwargs['nlat']
    nlon  = kwargs['nlon']

    # Initialize
    vv = VegInd(nlat=nlat, nlon=nlon)
    if kwargs['fill']:
        vv.attrs['title'] += ': Final, filled with persistence'
    else:
        vv.attrs['title'] += ': Preliminary, no persistence'
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    for year in range(date0.year, dateF.year+1):
        # Compute vegetation mask
        # ---
        if kwargs['regrid'] or kwargs['fill']:
            # Build/read land cover
            kwargs_cov = kwargs
            kwargs_cov['date0'] = datetime(year, 1, 1)
            kwargs_cov['dateF'] = datetime(year,12,31)
            cc = cover(**kwargs_cov)
            print('')

            ftype = cc['ftype'].values
            # Will need to make this a function in the class (remember
            # 0 indexing): Unclassified (17), water bodies (16), snow/ice (14),
            # wetlands (10)
#           mask = 1. - (ftype[17,:,:] + ftype[16,:,:] + ftype[14,:,:] +
#               0.5*ftype[10,:,:])
            # Not using wetlands even though it makes sense (closer to GIMMS)
            mask = 1. - (ftype[17,:,:] + ftype[16,:,:] + ftype[14,:,:])

        # Build/read daily vegetation indices
        # ---
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
            dateout = jdnow.strftime('%Y%m%d')

            print('===    ________ ' + jdnow.strftime('%Y-%m-%d') + '               ===')

            colveg = check_cols(jdnow, **kwargs)['colveg']
            dirget = path.join(data, colveg, syear, jdayget)
            fveg = headveg + dateout + '.nc'
            fpre = headpre + dateout + '.nc'

            # Download
            if kwargs['get']:
                print('===    ____________ Downloading          ===')
                download(colveg, dateget, dirget)

            if not kwargs['regrid'] and not kwargs['fill']: continue

            vvold = vv.copy(deep=True)

            # Read or regrid preliminary file
            if kwargs['regrid']:
                print('===    ____________ Regridding           ===')
                if path.isfile(fpre) and not kwargs['repro']:
                    vv = VegInd(xr.open_dataset(fpre))
                else:
                    try:
                        vv = vv.regrid(dirget, mask=mask)
                    except EOFError as message:
                        sys.stderr.write('No files to process, proceeding ...\n')
                    else:
                        pout = check_call(['mkdir', '-p', dirpre])
                        vv.to_netcdf(fpre)

            # Read or regrid filled file
            if kwargs['fill']:
                print('===    ____________ Filling              ===')
                if path.isfile(fveg) and not kwargs['repro']:
                    vv = VegInd(xr.open_dataset(fveg))
                else:
                    # Fill with persistence and compute fPAR
                    inan = np.logical_and(np.isnan(vv['NDVI'].values),
                        ~np.isnan(vvold['NDVI'].values))
                    vv['NDVI'].values[inan] = vvold['NDVI'].values[inan]

                    vv = vv.ndvi2fpar(cc['mode'].values)

                    pout = check_call(['mkdir', '-p', dirveg])
                    vv.to_netcdf(fveg)

            # Slightly terrifying
            if kwargs['get'] and kwargs['tidy']:
                pout = check_call(['rm', '-rf', dirget])

    if kwargs['regrid'] or kwargs['fill']: cc.close()
    return vv

def burn(**kwargs):
    '''Build (re)gridded MODIS/VIIRS burned area dataset'''

    print('')
    print('===    ____ Burned Area                  ===')

    # Check and read arguments
    kwargs = check_args(**kwargs)

    data  = kwargs['data']
    date0 = kwargs['date0']
    dateF = kwargs['dateF']
    nlat  = kwargs['nlat']
    nlon  = kwargs['nlon']

    # Initialize
    bb = Burn(nlat=nlat, nlon=nlon)
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    for year in range(date0.year, dateF.year+1):
        syear = str(year)
        jdyear = datetime(year, 1, 1)

        # Land cover definitions
        colcov  = check_cols(jdyear, **kwargs)['colcov']
        yearcov = min(year, YMAXCOV)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        ystrcov = datetime(yearcov, 1, 1).strftime('%Y')
        dircov  = path.join(data, colcov, ystrcov, '001')
        headcov = path.join(data, colcov, ystrcov, '001',
            colcov[:-4] + '.A' + ystrcov + '001.')

        # VCF definitions
        colvcf = check_cols(jdyear, **kwargs)['colvcf']
        yearvcf = min(year, YMAXVCF)
        datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
        ystrvcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y')
        dirvcf  = path.join(data, colvcf, ystrvcf, '065')
        headvcf = path.join(data, colvcf, ystrvcf, '065',
            colvcf[:-4] + '.A' + ystrvcf + '065.')

        if kwargs['regrid'] and kwargs['get']:
            print('===    ________ ' + syear + '                     ===')
            print('===    ____________ Downloading          ===')
            download(colcov, datecov, dircov)
            download(colvcf, datevcf, dirvcf)

        # Build burned area
        # ---
        dirout  = path.join(data, 'burn', syear)
        headmon = path.join(dirout, 'modvir_burn.' + restag + '.monthly.')
        headday = path.join(dirout, 'modvir_burn.' + restag + '.daily.')

        for nm in range(1,13):
            # Skip if before range
            if year == date0.year and nm < date0.month:
                continue

            jdmonth = datetime(year, nm, 1)
            dateget = jdmonth.strftime('%Y.%m.%d')
            jdayget = jdmonth.strftime('%j')

            print('===    ________ ' + jdmonth.strftime('%Y-%m') + '                  ===')

            # Download burned area
            colburn  = check_cols(jdmonth, **kwargs)['colburn']
            dirget   = path.join(data, colburn, syear, jdayget)
            headburn = path.join(data, colburn, syear, jdayget,
                colburn[:-4] + '.A' + syear + jdayget + '.')

            if kwargs['get']:
                print('===    ____________ Downloading          ===')
                download(colburn, dateget, dirget)

            if not kwargs['regrid']: continue

            # Regrid monthlies
            print('===    ____________ Regridding           ===')
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
                    if kwargs['get'] and kwargs['tidy']:
                        # Slightly terrifying
                        pout = check_call(['rm', '-rf', dirget])
                        pout = check_call(['rm', '-rf', dircov])
                    return bb

            # Slightly terrifying
            if kwargs['get'] and kwargs['tidy']:
                pout = check_call(['rm', '-rf', dirget])

        # Slightly terrifying
        if kwargs['get'] and kwargs['tidy']:
            pout = check_call(['rm', '-rf', dircov])

    return bb
