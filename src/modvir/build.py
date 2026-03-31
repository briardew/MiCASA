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
from modvir.patches import xarray as xr

from os import path, makedirs, remove, rmdir
from glob import glob
from datetime import datetime, timedelta
from calendar import monthrange

from modvir.config import (defaults, check_args, check_cols,
    YMINCOV, YMAXCOV, YMINVCF, YMAXVCF, FEXT)
from modvir.utils import download
from modvir.cover import Cover
from modvir.vegind import VegInd
from modvir.burn import Burn

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

    restag = 'x' + str(nlon) + '_y' + str(nlat)

    # Initialize
    cc = Cover(nlat=nlat, nlon=nlon)
    cc.attrs['ShortName'] = 'MICASA_COVER_Y'
    cc.attrs['LongName'] = ('MiCASA Yearly Land Cover ' +
        kwargs.get('Resolution', ''))
    cc.attrs['VersionID'] = ver
    cc.attrs['title'] = cc.attrs['LongName'] + ' v' + ver
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact', 'NorthernmostLatiude', 'WesternmostLongitude',
        'SouthernmostLatitude', 'EasternmostLongitude']:
        if key in kwargs: cc.attrs[key] = kwargs[key]

    for year in range(date0.year, dateF.year+1):
        jdnow = datetime(year, 1, 1)

        print(f'===    ________ {year}')

        # Land cover input vars
        colcov  = check_cols(jdnow, **kwargs)['colcov']
        yearcov = min(max(year, YMINCOV), YMAXCOV)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        dircov  = path.join(output, colcov, f'{yearcov}', '001')
        headcov = path.join(dircov, colcov[:-4] + f'.A{yearcov}001.')

        # VCF input vars
        colvcf  = check_cols(jdnow, **kwargs)['colvcf']
        yearvcf = min(max(year, YMINVCF), YMAXVCF)
        datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
        dirvcf  = path.join(output, colvcf, f'{yearvcf}', '065')
        headvcf = path.join(dirvcf, colvcf[:-4] + f'.A{yearvcf}065.')

        # Output vars
        dirout = path.join(output, 'cover')
        fgran  = f'MiCASA_v{ver}_cover_{restag}_yearly_{year}.{FEXT}'
        fout   = path.join(dirout, fgran)

        # Download if requested or needed for regrid
        get4regrid = kwargs['regrid'] and (not path.isfile(fout)
            or kwargs['force'])
        if kwargs['get'] or get4regrid:
            print('===    ____________ Downloading')
            download(colcov, datecov, dircov)
            download(colvcf, datevcf, dirvcf)

        if kwargs['regrid']:
            print('===    ____________ Regridding')
            if path.isfile(fout) and not kwargs['force']:
                cc = Cover(xr.open_dataset(fout))
            else:
                cc.attrs['RangeBeginningDate'] = f'{year}-01-01'
                cc.attrs['RangeBeginningTime'] = '00:00:00.000000'
                cc.attrs['RangeEndingDate'] = f'{year}-12-31'
                cc.attrs['RangeEndingTime'] = '23:59:59.999999'
                cc.attrs['GranuleID'] = fgran
                cc = cc.regrid(dircov, headcov, headvcf)
                makedirs(dirout, exist_ok=True)
                cc.to_netcdf(fout)

        # Slightly terrifying
        if kwargs['tidy']:
            try:
                for ff in glob(headcov + '*'): remove(ff)
                rmdir(path.join(output, colcov, f'{yearcov}', '001'))
                rmdir(path.join(output, colcov, f'{yearcov}'))
                rmdir(path.join(output, colcov))
            except Exception as e:
                print(e)

            try:
                for ff in glob(headvcf + '*'): remove(ff)
                rmdir(path.join(output, colvcf, f'{yearvcf}', '065'))
                rmdir(path.join(output, colvcf, f'{yearvcf}'))
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

    restag = 'x' + str(nlon) + '_y' + str(nlat)

    # Initialize
    vv = VegInd(nlat=nlat, nlon=nlon)
    vv.attrs['ShortName'] = 'MICASA_VEGIND_D'
    vv.attrs['LongName'] = ('MiCASA Daily Vegetation Indices ' +
        kwargs.get('Resolution', ''))
    vv.attrs['VersionID'] = ver
    vv.attrs['title'] = vv.attrs['LongName'] + ' v' + ver
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact', 'NorthernmostLatiude', 'WesternmostLongitude',
        'SouthernmostLatitude', 'EasternmostLongitude']:
        if key in kwargs: vv.attrs[key] = kwargs[key]

    for year in range(date0.year, dateF.year+1):
        # Compute vegetation mask
        # ---
        if kwargs['regrid'] or kwargs['fill']:
            # Build/read land cover
            kwargs_cov = kwargs
            kwargs_cov['get'] = False
            kwargs_cov['regrid'] = True
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
        dirpre  = path.join(output, 'vegpre', f'{year}')
        headpre = path.join(dirpre, f'MiCASA_v{ver}_vegpre_{restag}_daily_')
        dirind  = path.join(output, 'vegind', f'{year}')
        headind = path.join(dirind, f'MiCASA_v{ver}_vegind_{restag}_daily_')

        # Time period
        jday0 = max(datetime(year, 1, 1), date0)
        jdayF = min(datetime(year,12,31), dateF)
        ndays = (jdayF - jday0).days + 1
        for nd in range(ndays):
            # Day-specific strings
            jdnow = jday0 + timedelta(nd)

            print('===    ________ ' + jdnow.strftime('%Y-%m-%d'))

            # Vegetation input vars
            dateveg = jdnow.strftime('%Y.%m.%d')
            jdayveg = jdnow.strftime('%j')
            colveg  = check_cols(jdnow, **kwargs)['colveg']
            dirveg  = path.join(output, colveg, f'{year}', jdayveg)
            headveg = path.join(output, colveg, f'{year}', jdayveg,
                colveg[:-4] + f'.A{year}{jdayveg}.')

            # Output vars
            dateout = jdnow.strftime('%Y%m%d')
            find = headind + dateout + '.' + FEXT
            fpre = headpre + dateout + '.' + FEXT

            # Download if requested or needed for regrid
            get4regrid = kwargs['regrid'] and (not path.isfile(fpre)
                or kwargs['force'])
            if kwargs['get'] or get4regrid:
                print('===    ____________ Downloading')
                download(colveg, dateveg, dirveg)

            vvold = vv.copy(deep=True)

            # Read or regrid preliminary file
            if kwargs['regrid']:
                print('===    ____________ Regridding')
                if path.isfile(fpre) and not kwargs['force']:
                    vv = VegInd(xr.open_dataset(fpre))
                else:
                    vv.attrs['RangeBeginningDate'] = jdnow.strftime('%Y-%m-%d')
                    vv.attrs['RangeBeginningTime'] = '00:00:00.000000'
                    vv.attrs['RangeEndingDate'] = jdnow.strftime('%Y-%m-%d')
                    vv.attrs['RangeEndingTime'] = '23:59:59.999999'
                    # Some days have outages
                    try:
                        vv = vv.regrid(dirveg, mask=mask)
                    except EOFError as message:
                        sys.stderr.write('No files to process, proceeding ...\n')
                    else:
                        makedirs(dirpre, exist_ok=True)
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

                    vv.attrs['GranuleID'] = find

                    makedirs(dirind, exist_ok=True)
                    vv.to_netcdf(find)

            # Slightly terrifying
            if kwargs['tidy']:
                try:
                    for ff in glob(headveg + '*'): remove(ff)
                    for ff in glob('BROWSE.' + headveg + '*'): remove(ff)
                    rmdir(path.join(output, colveg, f'{year}', jdayveg))
                    rmdir(path.join(output, colveg, f'{year}'))
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

    restag = 'x' + str(nlon) + '_y' + str(nlat)

    # Initialize
    bb = Burn(nlat=nlat, nlon=nlon)
    bb.attrs['ShortName'] = 'MICASA_BURN_D'
    bb.attrs['LongName'] = ('MiCASA Daily Biomass Burning ' +
        kwargs.get('Resolution', ''))
    bb.attrs['VersionID'] = ver
    bb.attrs['title'] = bb.attrs['LongName'] + ' v' + ver
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact', 'NorthernmostLatiude', 'WesternmostLongitude',
        'SouthernmostLatitude', 'EasternmostLongitude']:
        if key in kwargs: bb.attrs[key] = kwargs[key]

    for year in range(date0.year, dateF.year+1):
        jdyear = datetime(year, 1, 1)

        print(f'===    ________ {year}')

        # Land cover input vars
        colcov  = check_cols(jdyear, **kwargs)['colcov']
        yearcov = min(max(year, YMINCOV), YMAXCOV)
        datecov = datetime(yearcov, 1, 1).strftime('%Y.%m.%d')
        dircov  = path.join(output, colcov, f'{yearcov}', '001')
        headcov = path.join(dircov, colcov[:-4] + f'.A{yearcov}001.')

        # VCF input vars
        colvcf = check_cols(jdyear, **kwargs)['colvcf']
        yearvcf = min(max(year, YMINVCF), YMAXVCF)
        datevcf = (datetime(yearvcf, 1, 1) + timedelta(64)).strftime('%Y.%m.%d')
        dirvcf  = path.join(output, colvcf, f'{yearvcf}', '065')
        headvcf = path.join(dirvcf, colvcf[:-4] + f'.A{yearvcf}065.')

        # Download if requested or needed for regrid
        if kwargs['get'] and kwargs['regrid']:
            print('===    ____________ Downloading')
            download(colcov, datecov, dircov)
            download(colvcf, datevcf, dirvcf)

        # Build burned area
        # ---
        dirout  = path.join(output, 'burn', f'{year}')
        headmon = path.join(dirout, f'MiCASA_v{ver}_burn_{restag}_monthly_')
        headday = path.join(dirout, f'MiCASA_v{ver}_burn_{restag}_daily_')

        for nm in range(1,13):
            # Skip if outside range
            if year == date0.year and nm < date0.month:
                continue
            elif year == dateF.year and dateF.month < nm:
                continue

            jdmonth = datetime(year, nm, 1)

            print('===    ________ ' + jdmonth.strftime('%Y-%m'))

            # Burned area input vars
            colburn  = check_cols(jdmonth, **kwargs)['colburn']
            dateburn = jdmonth.strftime('%Y.%m.%d')
            jdayburn = jdmonth.strftime('%j')
            dirburn  = path.join(output, colburn, f'{year}', jdayburn)
            headburn = path.join(dirburn, colburn[:-4] + f'.A{year}{jdayburn}.')

            # Output vars
            fmon = headmon + jdmonth.strftime('%Y%m') + '.' + FEXT

            # Download if requested or needed for regrid
            get4regrid = kwargs['regrid'] and (not path.isfile(fmon)
                or kwargs['force'])
            if kwargs['get'] or get4regrid:
                print('===    ____________ Downloading')
                download(colburn, dateburn, dirburn)

            if kwargs['regrid']:
                # Regrid monthlies
                print('===    ____________ Regridding')
                if path.isfile(fmon) and not kwargs['force']:
                    bb = Burn(xr.open_dataset(fmon))
                else:
#                   bb.attrs['RangeBeginningDate'] = jdnow.strftime('%Y-%m-%d')
#                   bb.attrs['RangeBeginningTime'] = '00:00:00.000000'
#                   bb.attrs['RangeEndingDate'] = jdnow.strftime('%Y-%m-%d')
#                   bb.attrs['RangeEndingTime'] = '23:59:59.999999'
#                   bb.attrs['GranuleID'] = fgran
                    bb = bb.regrid(dirburn, headburn, headcov, headvcf)
                    makedirs(dirout, exist_ok=True)
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
                    rmdir(path.join(output, colburn, f'{year}', jdayburn))
                    rmdir(path.join(output, colburn, f'{year}'))
                    rmdir(path.join(output, colburn))
                except Exception as e:
                    print(e)

            # Finished?
            if jdnow == dateF: break

        # Slightly terrifying
        if kwargs['tidy'] and kwargs['regrid']:
            try:
                for ff in glob(headcov + '*'): remove(ff)
                rmdir(path.join(output, colcov, f'{yearcov}', '001'))
                rmdir(path.join(output, colcov, f'{yearcov}'))
                rmdir(path.join(output, colcov))
            except Exception as e:
                print(e)

            try:
                for ff in glob(headvcf + '*'): remove(ff)
                rmdir(path.join(output, colvcf, f'{yearvcf}', '065'))
                rmdir(path.join(output, colvcf, f'{yearvcf}'))
                rmdir(path.join(output, colvcf))
            except Exception as e:
                print(e)

    return bb
