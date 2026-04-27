'''
MODIS/VIIRS processing utlities
'''

import sys
from os import path, makedirs
from glob import glob
from datetime import datetime
from requests.exceptions import HTTPError
from time import sleep
import earthaccess
import requests

def download(dtget, col, dirget, force=False):
    '''Download MODIS/VIIRS collections'''

    datedoy = dtget.strftime('%Y%j')
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
                print(f'No granules found matching {granny}', file=sys.stderr)
                return []

#           files = earthaccess.download(urls, dirget)
            break
        except HTTPError as e:
            print(f'{type(e).__name__}: {e}', file=sys.stderr)
        except Exception as e:
            raise

        sleep(SLEEPLEN)

    # Use requests for download since earthaccess is flaky
    makedirs(dirget, exist_ok=True)
    files = []
    for url in urls:
        file = path.join(dirget, url.split('/')[-1])
        for nn in range(MAXTRIES):
            try:
                response = requests.get(url, stream=True)
                response.raise_for_status()
                getfile = force or not path.isfile(file)
                if not force and path.isfile(file):
                    sizenow = path.getsize(file)
                    sizeout = int(response.headers.get('content-length', 0))
                    if sizenow != sizeout: getfile = True
                if getfile:
                    with open(file, 'wb') as fid:
                        fid.write(response.content)
                break
            except HTTPError as e:
                print(f'{type(e).__name__}: {e}', file=sys.stderr)
            except Exception as e:
                raise

            sleep(SLEEPLEN)
        files.append(file)

    return files

def _download_requests(dtget, col, dirget, force=False):
    '''Download MODIS/VIIRS collections'''

    datedoy = dtget.strftime('%Y%j')
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
                print(f'No granules found matching {granny}', file=sys.stderr)
                return []

            break
        except HTTPError as e:
            print(f'{type(e).__name__}: {e}', file=sys.stderr)
        except Exception as e:
            raise

        sleep(SLEEPLEN)

    return files

def swaphead(ff, headin, headout):
    '''Swap file in one MODIS/VIIRS collection with another'''

    fout = ff.replace(path.normpath(headin), path.normpath(headout), 1)
    parts = fout.split('.')
    flist = glob('.'.join(parts[:-3]) + '.*.' + parts[-1])
    flist.sort(key=path.getmtime)

    return flist[0] if len(flist) > 0 else None

def tidy(head):
    '''Clean up MODIS/VIIRS tiles'''

    try:
        for ff in glob(head + '*'): remove(ff)
        dd = path.dirname(head)
        # By construction, tiles have 3 levels of directories, e.g.
        # MCD12Q1.061/2001/001
        for nn in range(3):
            rmdir(dd)
            dd = path.dirname(dd)
    except Exception as e:
        print(f'{type(e).__name__}: {e}', file=sys.stderr)

    return
