'''
MODIS/VIIRS processing utlities
'''

from subprocess import call

# Allows for discover workaround
WGETCMD = 'wget'

def download(col, dateget, dirget, repro=False):
    '''Download MODIS/VIIRS collections from LP DAAC'''
    ardir = {'MOD':'MOLT', 'MYD':'MOLA', 'MCD':'MOTA', 'VNP':'VIIRS'}

    wgargs = '-r -np -nd -nv -e robots=off'
    if not repro: wgargs = '-nc ' + wgargs

#   Suboptimal, but needed for discover hack
    return call(WGETCMD + ' ' + wgargs + ' ' +
        'https://e4ftl01.cr.usgs.gov/' + ardir[col[:3]] + '/' + col + '/' +
        dateget + '/ -A "*.hdf,*.h5" -P ' + dirget, shell=True)
