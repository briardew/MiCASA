'''
MODIS/VIIRS processing utlities
'''

import sys
from os import path, makedirs
from glob import glob
from datetime import datetime
from time import sleep
import earthaccess
import requests

def download(granny, dirget, force=False):
    '''Download MODIS/VIIRS collections'''

    shorty = granny.split('.')[0]

    # Wrap download in a few tries in case of connection issues
    MAXTRIES = 10
    SLEEPLEN = 60
    for nn in range(MAXTRIES):
        try:
            auth = earthaccess.login(strategy='netrc')
            results = earthaccess.search_data(short_name=shorty,
                granule_name=granny)
            # Hack to deal with broken metadata in MCD43A4.061
            urls = []
            for rr in results:
                for ll in rr.data_links():
                    if not (ll.endswith('.jpg') or ll.endswith('.xml')):
                        urls.append(ll)

            if len(urls) == 0: return []
            # This croaks (because of parallelism?)
#           files = earthaccess.download(urls, dirget)
            break
        except requests.exceptions.HTTPError as e:
            print(f'{type(e).__name__}: {e}', file=sys.stderr)
        except Exception as e:
            raise

        sleep(SLEEPLEN)

    # Use requests for download since earthaccess croaks
    makedirs(dirget, exist_ok=True)
    files = [path.join(dirget, url.split('/')[-1]) for url in urls]
    with requests.Session() as ss:
        for url, file in zip(urls, files):
            for nn in range(MAXTRIES):
                try:
                    if not path.isfile(file) or force:
                        response = ss.get(url, stream=True)
                        response.raise_for_status()
                        with open(file, 'wb') as fid:
                            fid.write(response.content)
                    break
                except requests.exceptions.HTTPError as e:
                    print(f'{type(e).__name__}: {e}', file=sys.stderr)
                except Exception as e:
                    raise

                sleep(SLEEPLEN)

    return files

def swaphead(ff, listout):
    '''Swap file in one MODIS/VIIRS collection with another'''

    pin  = path.basename(ff).split('.')
    pout = path.basename(listout[0]).split('.')
    pattern = '.'.join(pout[0:2] + [pin[2], pout[3], ''])

    # Warn if len(matches) > 1?
    matches = [ss for ss in listout if pattern in ss]

    return matches[0] if len(matches) > 0 else None

def tidy(head, levs=0):
    '''Clean up MODIS/VIIRS tiles'''

    try:
        for ff in glob(head): remove(ff)
        dd = path.dirname(head)
        for nn in range(levs):
            rmdir(dd)
            dd = path.dirname(dd)
    except Exception as e:
        print(f'{type(e).__name__}: {e}', file=sys.stderr)

    return
