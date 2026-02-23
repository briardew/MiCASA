# * Can we back off the filling for NDVI? Looks like too much over
#   CONUS, but more stringent options have been untenable in tropics
# * Burned area tries to download entire year, only exits if
#   regridding (***FIXME***)
# * It would be nice, and more Pythonic, to move some of this to
#   the modules so that we could do something like
#       from datetime import datetime
#       from modvir import Cover
#       cc = Cover(datetime(2020, 1, 1))
#       cc.to_netcdf('test.nc4')
#   Right now I'm happy with things functioning as desired. We'll worry
#   about getting the interface right later.

import sys
import numpy as np
import xarray as xr

from os import path, makedirs, remove, rmdir
from glob import glob
from datetime import datetime, timedelta
from calendar import monthrange

from modvir.config import (defaults, check_args, check_cols,
    YMAXCOV, YMAXVCF)
from modvir.utils  import download
from modvir.cover  import Cover
from modvir.vegind import VegInd
from modvir.burn   import Burn

FEXT = 'nc4'

def cover(**kwargs):
    '''Build (re)gridded MiCASA land cover dataset'''

    print('')
    print('===    ____ Land Cover')

    # Check and read arguments
    kwargs = check_args(**kwargs)

    output = kwargs['output']
    date0 = kwargs['date0']
    dateF = kwargs['dateF']
    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    ver = kwargs['ver']

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
        dirout = path.join(output, 'cover')
        fout   = path.join(dirout, 'MiCASA_v' + ver + '_cover_' + restag +
            '_yearly_' + syear + '.' + FEXT)

        print('===    ________ ' + syear)

        # Land cover vars
        colcov  = check_cols(jdnow, **kwargs)['colcov']
        yearcov = min(year, YMAXCOV)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        ystrcov = datetime(yearcov, 1, 1).strftime('%Y')
        dircov  = path.join(output, colcov, ystrcov, '001')
        headcov = path.join(output, colcov, ystrcov, '001',
            colcov[:-4] + '.A' + ystrcov + '001.')

        # VCF vars
        colvcf  = check_cols(jdnow, **kwargs)['colvcf']
        yearvcf = min(year, YMAXVCF)
        datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
        ystrvcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y')
        dirvcf  = path.join(output, colvcf, ystrvcf, '065')
        headvcf = path.join(output, colvcf, ystrvcf, '065',
            colvcf[:-4] + '.A' + ystrvcf + '065.')

        if kwargs['get']:
            print('===    ____________ Downloading')
            download(colcov, datecov, dircov)
            download(colvcf, datevcf, dirvcf)

        # Read or regrid
        if not kwargs['regrid']: continue

        print('===    ____________ Regridding')
        if path.isfile(fout) and not kwargs['force']:
            cc = Cover(xr.open_dataset(fout))
        else:
            makedirs(dirout, exist_ok=True)
            cc = cc.regrid(dircov, headcov, headvcf)
            cc.to_netcdf(fout)

        # Slightly terrifying
        if kwargs['tidy']:
            try:
                for ff in glob(headcov + '*'): remove(ff)
                rmdir(path.join(output, colcov, ystrcov, '001'))
                rmdir(path.join(output, colcov, ystrcov))
                rmdir(path.join(output, colcov))
            except Exception as e:
                print(e)

            try:
                for ff in glob(headvcf + '*'): remove(ff)
                rmdir(path.join(output, colvcf, ystrvcf, '065'))
                rmdir(path.join(output, colvcf, ystrvcf))
                rmdir(path.join(output, colvcf))
            except Exception as e:
                print(e)

    return cc

def vegind(**kwargs):
    '''Build (re)gridded MiCASA vegetation indices dataset'''

    print('')
    print('===    ____ Vegetation Indicies')

    # Check and read arguments
    kwargs = check_args(**kwargs)

    output = kwargs['output']
    date0 = kwargs['date0']
    dateF = kwargs['dateF']
    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    ver = kwargs['ver']

    # Initialize
    vv = VegInd(nlat=nlat, nlon=nlon)
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
        dirpre  = path.join(output, 'vegpre', syear)
        headpre = path.join(dirpre, 'MiCASA_v' + ver + '_vegpre_' +
            restag + '_daily_')
        dirind  = path.join(output, 'vegind', syear)
        headind = path.join(dirind, 'MiCASA_v' + ver + '_vegind_' +
            restag + '_daily_')

        # Time period
        jday0 = max(datetime(year, 1, 1), date0)
        jdayF = min(datetime(year,12,31), dateF)
        ndays = (jdayF - jday0).days + 1
        for nd in range(ndays):
            # Day-specific strings
            jdnow = jday0 + timedelta(nd)

            print('===    ________ ' + jdnow.strftime('%Y-%m-%d'))

            # Vegetation vars
            dateveg = jdnow.strftime('%Y.%m.%d')
            jdayveg = jdnow.strftime('%j')
            colveg  = check_cols(jdnow, **kwargs)['colveg']
            dirveg  = path.join(output, colveg, syear, jdayveg)
            headveg = path.join(output, colveg, syear, jdayveg,
                colveg[:-4] + '.A' + syear + jdayveg + '.')

            dateout = jdnow.strftime('%Y%m%d')
            find = headind + dateout + '.' + FEXT
            fpre = headpre + dateout + '.' + FEXT

            # Download
            if kwargs['get']:
                print('===    ____________ Downloading')
                download(colveg, dateveg, dirveg)

            if not kwargs['regrid'] and not kwargs['fill']: continue

            vvold = vv.copy(deep=True)

            # Read or regrid preliminary file
            if kwargs['regrid']:
                print('===    ____________ Regridding')
                if path.isfile(fpre) and not kwargs['force']:
                    vv = VegInd(xr.open_dataset(fpre))
                else:
                    try:
                        vv = vv.regrid(dirveg, mask=mask)
                    except EOFError as message:
                        sys.stderr.write('No files to process, proceeding ...\n')
                    else:
                        makedirs(dirpre, exist_ok=True)
                        vv.attrs['title'] += ' (Preliminary, no persistence)'
                        vv.to_netcdf(fpre)

            # Read or regrid filled file
            if kwargs['fill']:
                print('===    ____________ Filling')
                if path.isfile(find) and not kwargs['force']:
                    vv = VegInd(xr.open_dataset(find))
                else:
                    # Fill with persistence and compute fPAR
                    inan = np.logical_and(np.isnan(vv['NDVI'].values),
                        ~np.isnan(vvold['NDVI'].values))
                    vv['NDVI'].values[inan] = vvold['NDVI'].values[inan]
                    vv = vv.ndvi2fpar(cc['mode'].values)

                    makedirs(dirind, exist_ok=True)
                    vv.attrs['title'] += ' (Final, filled with persistence)'
                    vv.to_netcdf(find)

            # Slightly terrifying
            if kwargs['tidy']:
                try:
                    for ff in glob(headveg + '*'): remove(ff)
                    for ff in glob('BROWSE.' + headveg + '*'): remove(ff)
                    rmdir(path.join(output, colveg, syear, jdayveg))
                    rmdir(path.join(output, colveg, syear))
                    rmdir(path.join(output, colveg))
                except Exception as e:
                    print(e)

    if kwargs['regrid'] or kwargs['fill']: cc.close()

    return vv

def burn(**kwargs):
    '''Build (re)gridded MiCASA burned area dataset'''

    print('')
    print('===    ____ Burned Area')

    # Check and read arguments
    kwargs = check_args(**kwargs)

    output = kwargs['output']
    date0 = kwargs['date0']
    dateF = kwargs['dateF']
    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    ver = kwargs['ver']

    # Initialize
    bb = Burn(nlat=nlat, nlon=nlon)
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    for year in range(date0.year, dateF.year+1):
        syear = str(year)
        jdyear = datetime(year, 1, 1)

        print('===    ________ ' + syear)

        # Land cover vars
        colcov  = check_cols(jdyear, **kwargs)['colcov']
        yearcov = min(year, YMAXCOV)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        ystrcov = datetime(yearcov, 1, 1).strftime('%Y')
        dircov  = path.join(output, colcov, ystrcov, '001')
        headcov = path.join(output, colcov, ystrcov, '001',
            colcov[:-4] + '.A' + ystrcov + '001.')

        # VCF vars
        colvcf = check_cols(jdyear, **kwargs)['colvcf']
        yearvcf = min(year, YMAXVCF)
        datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
        ystrvcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y')
        dirvcf  = path.join(output, colvcf, ystrvcf, '065')
        headvcf = path.join(output, colvcf, ystrvcf, '065',
            colvcf[:-4] + '.A' + ystrvcf + '065.')

        if kwargs['get'] and kwargs['regrid']:
            print('===    ____________ Downloading')
            download(colcov, datecov, dircov)
            download(colvcf, datevcf, dirvcf)

        # Build burned area
        # ---
        dirout  = path.join(output, 'burn', syear)
        headmon = path.join(dirout, 'MiCASA_v' + ver + '_burn_' +
            restag + '_monthly_')
        headday = path.join(dirout, 'MiCASA_v' + ver + '_burn_' +
            restag + '_daily_')

        for nm in range(1,13):
            # Skip if outside range
            if year == date0.year and nm < date0.month:
                continue
            elif year == dateF.year and dateF.month < nm:
                continue

            jdmonth = datetime(year, nm, 1)

            print('===    ________ ' + jdmonth.strftime('%Y-%m'))

            # Burned area vars
            colburn  = check_cols(jdmonth, **kwargs)['colburn']
            dateburn = jdmonth.strftime('%Y.%m.%d')
            jdayburn = jdmonth.strftime('%j')
            dirburn  = path.join(output, colburn, syear, jdayburn)
            headburn = path.join(output, colburn, syear, jdayburn,
                colburn[:-4] + '.A' + syear + jdayburn + '.')

            if kwargs['get']:
                print('===    ____________ Downloading')
                download(colburn, dateburn, dirburn)

            if not kwargs['regrid']: continue

            # Regrid monthlies
            print('===    ____________ Regridding')
            fmon = headmon + jdmonth.strftime('%Y%m') + '.' + FEXT
            if path.isfile(fmon) and not kwargs['force']:
                bb = Burn(xr.open_dataset(fmon))
            else:
                makedirs(dirout, exist_ok=True)
                bb = bb.regrid(dirburn, headburn, headcov, headvcf)
                bb.to_netcdf(fmon)

            # Output dailies
            ndays = monthrange(year, nm)[1]
            for nd in range(1,ndays+1):
                jdnow = datetime(year, nm, nd)
                fday  = headday + jdnow.strftime('%Y%m%d') + '.' + FEXT
                if not path.isfile(fday) or kwargs['force']: 
                    bbnow = bb.daysel((jdnow - jdyear).days + 1)
                    bbnow.to_netcdf(fday)

                # Finished?
                if jdnow == dateF: break

            # Slightly terrifying
            if kwargs['tidy']:
                try:
                    for ff in glob(headburn + '*'): remove(ff)
                    rmdir(path.join(output, colburn, syear, jdayburn))
                    rmdir(path.join(output, colburn, syear))
                    rmdir(path.join(output, colburn))
                except Exception as e:
                    print(e)

            # Finished?
            if jdnow == dateF: break

        # Slightly terrifying
        if kwargs['tidy'] and kwargs['regrid']:
            try:
                for ff in glob(headcov + '*'): remove(ff)
                rmdir(path.join(output, colcov, ystrcov, '001'))
                rmdir(path.join(output, colcov, ystrcov))
                rmdir(path.join(output, colcov))
            except Exception as e:
                print(e)

            try:
                for ff in glob(headvcf + '*'): remove(ff)
                rmdir(path.join(output, colvcf, ystrvcf, '065'))
                rmdir(path.join(output, colvcf, ystrvcf))
                rmdir(path.join(output, colvcf))
            except Exception as e:
                print(e)

    return bb
