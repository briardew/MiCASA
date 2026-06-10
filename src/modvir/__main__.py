#!/usr/bin/env python3
"""
MODIS/VIIRS land cover, vegetation index, and burned area generator
"""

import sys
import argparse
from datetime import datetime

from modvir.config import defaults
from modvir import cover, vegind, burn

# Parse command-line options
NAMELIST = ['cover', 'vegind', 'burn', 'all']
MODELIST = ['get', 'regrid', 'fill', 'all']

parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.ArgumentDefaultsHelpFormatter,
)

# fmt: off
parser.add_argument(
    'name', metavar='name', type=str, choices=NAMELIST,
    help='name of dataset to build: ' + ', '.join(NAMELIST),
)
parser.add_argument(
    '-m', '--mode', metavar='MODE', type=str, choices=MODELIST, default='all',
    help='operation mode: ' + ', '.join(MODELIST),
)
parser.add_argument(
    '-p', '--product', type=str, default=defaults['product'], help='product name',
)
parser.add_argument('-v', '--ver', type=str, default=defaults['ver'], help='version')
parser.add_argument(
    '--beg', metavar='YYYY-MM-DD', type=str,
    default=defaults['dtbeg'].strftime('%Y-%m-%d'), help='begin date',
)
parser.add_argument(
    '--end', metavar='YYYY-MM-DD', type=str,
    default=defaults['dtend'].strftime('%Y-%m-%d'), help='end date',
)
parser.add_argument('--nlat', type=int, default=defaults['nlat'], help='latitude dimension')
parser.add_argument('--nlon', type=int, default=defaults['nlon'], help='longitude dimension')
parser.add_argument(
    '-o', '--output', metavar='DIR', type=str, default=defaults['output'],
    help='output directory',
)
# These are hard coded, but a pain to do right
parser.add_argument('-f', '--force', action='store_true', help='overwrite files')
parser.add_argument('-t', '--tidy', action='store_true', help='remove downloads')
# Not supported yet
#parser.add_argument('--yaml', help='yaml settings file')
# fmt: on


def main():
    # Construct argument dictionary
    kwargs = vars(parser.parse_args())

    # Convert command-line args to function args
    # ---
    dtbeg = datetime.strptime(kwargs.pop('beg'), '%Y-%m-%d')
    dtend = datetime.strptime(kwargs.pop('end'), '%Y-%m-%d')

    # Execution mode
    mode = kwargs.pop('mode')
    if mode == 'get' or mode[:3] == 'acq' or mode[:4] == 'down':
        kwargs['get'] = True
        kwargs['regrid'] = False
        kwargs['fill'] = False
    elif mode == 'regrid':
        kwargs['get'] = False
        kwargs['regrid'] = True
        kwargs['fill'] = False
    elif mode == 'fill':
        kwargs['get'] = False
        kwargs['regrid'] = True
        kwargs['fill'] = True
    elif mode == 'all':
        kwargs['get'] = True
        kwargs['regrid'] = True
        kwargs['fill'] = True
    else:
        raise ValueError('Unsupported mode: ' + mode)

    # Some helpful? output
    print('====================================================')
    print('===        MODIS/VIIRS processing utility        ===')
    print('====================================================')
    print('')
    print('Arguments:')
    print(f'    beg = {dtbeg:%Y-%m-%d}')
    print(f'    end = {dtend:%Y-%m-%d}')
    for key in kwargs:
        print(f'    {key} = {kwargs[key]}')
    print('')

    name = kwargs.pop('name')
    if name == 'cover':
        cover.build(dtbeg, dtend, **kwargs)
    elif name == 'vegind':
        vegind.build(dtbeg, dtend, **kwargs)
    elif name == 'burn':
        burn.build(dtbeg, dtend, **kwargs)
    elif name == 'all':
        # vegind will build cover
        vegind.build(dtbeg, dtend, **kwargs)
        burn.build(dtbeg, dtend, **kwargs)
    else:
        raise ValueError('Unsupported name: ' + name)


if __name__ == '__main__':
    sys.exit(main())
