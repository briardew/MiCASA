#!/usr/bin/env python3
'''
Entry point for modvir module
'''

import sys
import argparse
from datetime import datetime

from modvir.config import defaults
from modvir import build

# Parse command-line options
NAMELIST = ['cover', 'vegind', 'burn', 'all']
MODELIST = ['get', 'regrid', 'fill', 'all']

parser = argparse.ArgumentParser(description=__doc__,
    usage='modvir name [options]',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('name', metavar='name', type=str, choices=NAMELIST,
    help='name of product to build: ' + ', '.join(NAMELIST))
parser.add_argument('-m', '--mode', metavar='MODE', type=str, choices=MODELIST,
    default='all', help='operation mode: ' + ', '.join(MODELIST))
parser.add_argument('-v', '--ver', default=defaults['ver'], help='version')
parser.add_argument('--beg', metavar='YYYY-MM-DD',
    default=defaults['date0'].strftime('%Y-%m-%d'), help='begin date')
parser.add_argument('--end', metavar='YYYY-MM-DD',
    default=defaults['dateF'].strftime('%Y-%m-%d'), help='end date')
parser.add_argument('--nlat', type=int, default=defaults['nlat'],
    help='latitude dimension')
parser.add_argument('--nlon', type=int, default=defaults['nlon'],
    help='longitude dimension')
parser.add_argument('-o', '--output', metavar='DIR', default=defaults['output'],
    help='output directory')
# These are hard coded, but a pain to do right
parser.add_argument('-f', '--force', action='store_true',
    help='overwrite files')
parser.add_argument('-t', '--tidy', action='store_true',
    help='remove downloads')
parser.add_argument('--yaml', help='yaml settings file')

def main():
    # Construct argument dictionary
    kwargs = vars(parser.parse_args())

    # Convert command-line args to function args
    kwargs['date0'] = datetime.strptime(kwargs.pop('beg'), '%Y-%m-%d')
    kwargs['dateF'] = datetime.strptime(kwargs.pop('end'), '%Y-%m-%d')

    # Execution mode
    mode = kwargs.pop('mode')
    if mode == 'get' or mode[:3] == 'acq' or mode[:4] == 'down':
        kwargs['get']    = True
        kwargs['regrid'] = False
        kwargs['fill']   = False
    elif mode == 'regrid':
        kwargs['get']    = False
        kwargs['regrid'] = True
        kwargs['fill']   = False
    elif mode == 'fill':
        kwargs['get']    = False
        kwargs['regrid'] = True
        kwargs['fill']   = True
    elif mode == 'all':
        kwargs['get']    = True
        kwargs['regrid'] = True
        kwargs['fill']   = True
    else:
        raise ValueError('Unsupported mode: ' + mode)

    # Some helpful? output
    print('============================================')
    print('===    MODIS/VIIRS processing utility    ===')
    print('============================================')
    print('')
    print('kwargs = {')
    for key in kwargs:
        print("    '" + key + "': " + str(kwargs[key]) + ",")
    print('}')

    name = kwargs.pop('name')
    if name == 'cover':
        build.cover(**kwargs)
    elif name == 'vegind':
        build.vegind(**kwargs)
    elif name == 'burn':
        build.burn(**kwargs)
    elif name == 'all':
        # vegind will build cover
        build.vegind(**kwargs)
        build.burn(**kwargs)
    else:
        raise ValueError('Unsupported name: ' + name)

if __name__ == '__main__':
    sys.exit(main())
