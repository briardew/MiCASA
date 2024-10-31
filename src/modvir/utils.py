'''
MODIS/VIIRS processing utlities
'''

from subprocess import call
from os import path
from glob import glob

# Allows for discover workaround
WGETCMD = 'wget'

def download(col, dateget, dirget, repro=False):
    '''Download MODIS/VIIRS collections from LP DAAC'''
    ardir = {'MOD':'MOLT', 'MYD':'MOLA', 'MCD':'MOTA', 'VNP':'VIIRS'}

    wgargs = '-r -np -nd -nv -e robots=off'
    if not repro: wgargs = '-nc ' + wgargs

    # Suboptimal, but needed for discover hack
    return call(WGETCMD + ' ' + wgargs + ' ' +
        'https://e4ftl01.cr.usgs.gov/' + ardir[col[:3]] + '/' + col + '/' +
        dateget + '/ -A "*.hdf,*.h5" -P ' + dirget, shell=True)

def swaphead(ff, headin, headout):
    '''Swap one MODIS/VIIRS collection header with another'''

    parts = ff.replace(headin, headout, 1).split('.')
    flist = glob('.'.join(parts[:-3]) + '.*.' + parts[-1])
    flist.sort(key=path.getmtime)

    return flist[0] if len(flist) > 0 else None
