'''
MODIS/VIIRS processing utlities
'''

from os import path
from glob import glob
from datetime import datetime
from requests.exceptions import HTTPError
from time import sleep
import earthaccess

def download(col, dateget, dirget, force=False):
    '''Download MODIS/VIIRS collections from LP DAAC'''

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
            auth = earthaccess.login(strategy='netrc')
            results = earthaccess.search_data(short_name=shorty,
                granule_name=granny)
            # Hack to deal with broken metadata MCD43A4.061
            urls = []
            for rr in results:
                for ll in rr.data_links():
                    if not (ll.endswith('.jpg') or ll.endswith('.xml')):
                        urls.append(ll)
            if len(urls) == 0:
                print(f'No granules found matching {granny}')
                return

            files = earthaccess.download(urls, dirget)
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
