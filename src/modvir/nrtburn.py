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

from modvir.config import (defaults, check_args, check_cols,
    YMAXCOV, YMAXVCF)
from modvir.utils import download

from modvir.cover import Cover
from modvir.vegind import VegInd
from modvir.burn import Burn

def nrtburn(**kwargs):
    '''Build NRT burned area dataset'''

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
    restag = 'x' + str(nlon) + '_y' + str(nlat)

    # Loop over years
    for year in range(date0.year, dateF.year+1):
        syear = str(year)
        jdyear = datetime(year, 1, 1)

        # Build burned area
        # ---
        dirout  = path.join(data, 'burn', syear)
        headmon = path.join(dirout, 'modvir_burn.' + restag + '.monthly.')
        headday = path.join(dirout, 'modvir_burn.' + restag + '.daily.')

        for nm in range(1,13):
            jdmon = datetime(year, nm, 1)

            print('===    ________ ' + jdmon.strftime('%Y-%m') + '                  ===')

            # Output dailies
            ndays = monthrange(year, nm)[1]
            for nd in range(1,ndays+1):
                jdnow = datetime(year, nm, nd)
                fday  = headday + jdnow.strftime('%Y%m%d') + '.nc'
                if not path.isfile(fday) or kwargs['repro']: 
                    bbnow.to_netcdf(fday)

    return bb
