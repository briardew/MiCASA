'''
MODIS/VIIRS processing utlities
'''

from os import path
from glob import glob
#from subprocess import call
from datetime import datetime
from requests.exceptions import HTTPError
from time import sleep
import earthaccess

def download(col, dateget, dirget, force=False):
    '''Download MODIS/VIIRS collections from LP DAAC'''
#    ardir = {'MOD':'MOLT', 'MYD':'MOLA', 'MCD':'MOTA', 'VNP':'VIIRS'}
#
#    wgargs = '-r -np -nd -nv -e robots=off'
#    if not force: wgargs = '-nc ' + wgargs
#
#    # Suboptimal, but needed for discover hack
#    return call('wget ' + wgargs + ' ' +
#        'https://e4ftl01.cr.usgs.gov/' + ardir[col[:3]] + '/' + col + '/' +
#        dateget + '/ -A "*.hdf,*.h5" -P "' + dirget + '"', shell=True)

    # Convert date input (originally designed for %Y.%m.%d format)
    if len(dateget) == 10:
        datedoy = datetime.strptime(dateget.replace('.','-'),
            '%Y-%m-%d').strftime('%Y%j')
    elif len(dateget) == 7:
        datedoy = dateget
    else:
        raise ValueError(f'Unrecognized date format: {dateget}')

    shorty = col[:-4]
    granny = shorty + '.A' + datedoy + '.*.' + col[-3:] + '.*'

    # Wrap download in a few tries in case of connection issues
    MAXTRIES = 10
    SLEEPLEN = 60
    for nn in range(MAXTRIES):
        try:
            auth = earthaccess.login(strategy="netrc")
            results = earthaccess.search_data(short_name=shorty,
                granule_name=granny)
            if len(results) == 0:
                print(f'No granules found matching {granny}')
                return

            files = earthaccess.download(results, dirget)
            break
        except HTTPError as e:
            print(e)
        except Exception as e:
            raise

        sleep(SLEEPLEN)

    return

def swaphead(ff, headin, headout):
    '''Swap one MODIS/VIIRS collection header with another'''

    parts = ff.replace(headin, headout, 1).split('.')
    flist = glob('.'.join(parts[:-3]) + '.*.' + parts[-1])
    flist.sort(key=path.getmtime)

    return flist[0] if len(flist) > 0 else None
