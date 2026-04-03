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

    # Define restag and attrs for later
    restag = 'x' + str(nlon) + '_y' + str(nlat)
    longname = ('MiCASA Yearly Land Cover ' +
        f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    attrs = {
        'ShortName':'MICASA_COVER_Y',
        'LongName':longname,
        'title':f'{longname} v{ver}',
        'VersionID':ver,
    }
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact']:
        if key in kwargs: attrs[key] = kwargs[key]

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

        # Download if needed for regrid or requested
        get4regrid = kwargs['regrid'] and (not path.isfile(fout)
            or kwargs['force'])
        if get4regrid or kwargs['get']:
            print('===    ____________ Downloading')
            download(colcov, datecov, dircov)
            download(colvcf, datevcf, dirvcf)

        if kwargs['regrid']:
            print('===    ____________ Regridding')
            if path.isfile(fout) and not kwargs['force']:
                cc = Cover(xr.open_dataset(fout))
            else:
                cc = Cover(time=jdnow, nlat=nlat, nlon=nlon)
                # Weird syntax so attrs are ordered how I like
                cc.attrs = {**attrs, **cc.attrs}
                cc = cc.regrid(headcov, headvcf)

                makedirs(dirout, exist_ok=True)
                cc.to_netcdf(fout, unlimited_dims=['time'])

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

    # Define restag and attrs for later
    restag = 'x' + str(nlon) + '_y' + str(nlat)
    longname = ('MiCASA Daily Vegetation Indices ' +
        f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    attrs = {'ShortName':'MICASA_VEGIND_D', 'LongName':longname,
        'title':f'{longname} v{ver}', 'VersionID':ver}
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact']:
        if key in kwargs: attrs[key] = kwargs[key]

    # Initialize with NaNs (for vvold)
    vv = VegInd(time=date0, nlat=nlat, nlon=nlon)
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

            # Recall values have a singleton time dim
            ftype = cc['ftype'].values[0,:,:,:]
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
        dirout  = path.join(output, 'vegind', f'{year}')
        headout = path.join(dirout, f'MiCASA_v{ver}_vegind_{restag}_daily_')

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
            fout = headout + dateout + '.' + FEXT
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
                    try:
                        vv = VegInd(time=jdnow, nlat=nlat, nlon=nlon)
                        # Weird syntax so attrs are ordered how I like
                        vv.attrs = {**attrs, **vv.attrs}
                        vv = vv.regrid(dirveg, mask=mask)
                    except EOFError as message:
                        sys.stderr.write('No files to process, proceeding ...\n')
                    else:
                        makedirs(dirpre, exist_ok=True)
                        vv.to_netcdf(fpre, unlimited_dims=['time'])

            # Read or regrid filled file
            if kwargs['fill']:
                print('===    ____________ Filling')
                if path.isfile(fout) and not kwargs['force']:
                    vv = VegInd(xr.open_dataset(fout))
                else:
                    # Fill with persistence and compute fPAR
                    inan = np.logical_and(np.isnan(vv['NDVI'].values),
                        ~np.isnan(vvold['NDVI'].values))
                    vv['NDVI'].values[inan] = vvold['NDVI'].values[inan]
                    vv = vv.ndvi2fpar(cc['mode'].values)

                    makedirs(dirout, exist_ok=True)
                    vv.to_netcdf(fout, unlimited_dims=['time'])

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

    # Define restag and attributes (atmon & atday) for later
    restag = 'x' + str(nlon) + '_y' + str(nlat)
    longnmon = ('MiCASA Monthly Biomass Burning ' +
        f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    atmon = {'ShortName':'MICASA_BURN_M', 'LongName':longnmon,
        'title':f'{longnmon} v{ver}', 'VersionID':ver}
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact']:
        if key in kwargs: atmon[key] = kwargs[key]
    longnday = ('MiCASA Daily Biomass Burning ' +
        f'{round(180/nlat,3)} degree x {round(360/nlon,3)} degree')
    atday = {'ShortName':'MICASA_BURN_D', 'LongName':longnday,
        'title':f'{longnday} v{ver}', 'VersionID':ver}
    for key in ['Format', 'Conventions', 'ProcessingLevel', 'institution',
        'contact']:
        if key in kwargs: atday[key] = kwargs[key]

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
                ndays = monthrange(year, nm)[1]

                if path.isfile(fmon) and not kwargs['force']:
                    bbmon = Burn(xr.open_dataset(fmon))
                else:
                    bbmon = Burn(time=jdmonth, nlat=nlat, nlon=nlon, ndays=ndays)
                    # Weird syntax so attrs are ordered how I like
                    bbmon.attrs = {**atmon, **bbmon.attrs}
                    bbmon = bbmon.regrid(headburn, headcov, headvcf)

                    makedirs(dirout, exist_ok=True)
                    bbmon.to_netcdf(fmon, unlimited_dims=['time'])

                # Output dailies
                for nd in range(1,ndays+1):
                    jdnow = datetime(year, nm, nd)
                    fday  = headday + jdnow.strftime('%Y%m%d') + '.' + FEXT
                    if not path.isfile(fday) or kwargs['force']: 
                        bb = Burn(time=jdnow, nlat=nlat, nlon=nlon)
                        # Weird syntax so attrs are ordered how I like
                        bb.attrs = {**atday, **bb.attrs}

                        # Switch to preserve v1 "bug" that averaged burn dates
                        if ver == '1':
                            nd = (jdnow - jdyear).days + 1
                            iok = bbmon['date'].values == nd
                            ino = bbmon['date'].values != nd

                            for var in ['batot', 'baherb', 'bawood', 'badefo']:
                                bb[var].values[iok] = bbmon[var].values[iok]
                                bb[var].values[ino] = bbmon[var].values[ino]*0
                            bb.attrs['input_files'] = bbmon.attrs['input_files']
                        else:
                            bb = bb.regrid(headburn, headcov, headvcf, nd)

                        bb.to_netcdf(fday, unlimited_dims=['time'])

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

    # Not sure why this is here of it's useful
    return bbmon
