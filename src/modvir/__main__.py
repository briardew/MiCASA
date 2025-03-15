#!/usr/bin/env python3
'''
Entry point for modvir module
'''

import sys
from datetime import datetime
from argparse import ArgumentParser

from modvir.config import defaults
from modvir import build

# Parse command-line options
class MVParser(ArgumentParser):
    def error(self, message):
        sys.stderr.write('\n*** ERROR *** %s\n\n' % message)
        self.print_help()
        sys.exit(2)

# Read arguments
parser = MVParser(description=__doc__,
    usage='modvir name [options]')
parser.add_argument('name', help='name of product to build: cover, vegind, ' +
    'burn, all')
parser.add_argument('--mode', help='operation mode (get, regrid, fill, ' +
    'all, default: %(default)s)', default='all')
parser.add_argument('--data', help='data directory (default: %(default)s)',
    default=defaults['data'])
parser.add_argument('--beg', help='begin date (default: %(default)s)',
    default=defaults['date0'].strftime('%Y-%m-%d'))
parser.add_argument('--end', help='end date (default: %(default)s)',
    default=defaults['dateF'].strftime('%Y-%m-%d'))
parser.add_argument('--nlat', help='latitude dimension (default: %(default)s)',
    type=int, default=defaults['nlat'])
parser.add_argument('--nlon', help='longitude dimension (default: %(default)s)',
    type=int, default=defaults['nlon'])
parser.add_argument('--ver', help='version (default: %(default)s)',
    default='1')
# These are hard coded, but a pain to do right
parser.add_argument('--repro', help='reprocess/overwrite (default: false)',
    action='store_true')
parser.add_argument('--nrt', help='near real time mode (default: false)',
    action='store_true')
parser.add_argument('--tidy', help='remove downloads (default: false)',
    action='store_true')
parser.add_argument('--rc', help='run control settings yaml file')

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
