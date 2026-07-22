"""
MODIS/VIIRS configuration module
"""

from datetime import datetime
from os import path

# Land cover type variable, number of types, number of missing type
# NB: fPAR and burned area both depend on these choices
# fmt: off
LCVAR = 'LC_Type1'
NTYPE = 18							# Including unclassified as a type
NMISS = 16							# Missing tiles assumed water

FEXT = 'nc4'							# Output file extension; see defaults['Format'] below

YEAR0 = 1980							# Year that all timestamps are based on
TIME0 = datetime(YEAR0, 1, 1)					# YEAR0 in datetime format
TUNITS = 'days since ' + TIME0.strftime('%Y-%m-%d')		# Time units string
# fmt: on

defaults = {
    # NB: NBAR data start 2000-02-16
    'dtbeg': datetime(2001, 1, 1),
    'dtend': datetime.now(),
    'prod': 'MiCASA',
    'ver': 'NRT',
    # 0.1 deg regular grid
    'nlat': 1800,
    'nlon': 3600,
    'output': '.',
    # Run switches
    'force': False,
    'tidy': False,
    # Translated from args; fixme?
    'regrid': True,
    'get': True,
    'fill': True,
    # Output metadata
    'Format': 'netCDF',
    'Conventions': 'CF-1.9',
    'ProcessingLevel': '4',
    'institution': 'NASA Goddard Space Flight Center',
    'contact': 'Brad Weir <brad.weir@nasa.gov>',
}


def fillargs(dtval, **kwargs):
    """Check and fille arguments"""

    # Set anything unspecified to default
    # ---
    for key in defaults.keys() - ['dtbeg', 'dtend']:
        kwargs[key] = kwargs.get(key, defaults[key])

    ver = kwargs['ver']
    # Split full version (###-XYZ) into number (###) and domain (XYZ)
    vernum, _, domain = ver.partition('-')

    # Fill resolution tag
    # ---
    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    kwargs['restag'] = f'x{nlon}_y{nlat}'

    # Fill collection names (if unspecified)
    # ---
    # Minimum and maximum years of land cover and VCF collections
    # Note: MOD44B.006 is only available on NCCS Discover and maybe Google Earth Engine
    # Years 2003-2006 of MOD44B.006 on Discover were lost and recovered from GEE.
    YMINCOV = 2001
    YMAXCOV = datetime.now().year - 2
    YMINVCF = 2001
    YMAXVCF = 2020	
    # For reproducability
    if vernum == '1':
        YMAXCOV = 2021

    # Should these be specified in defaults?
    colcov = 'MCD12Q1.061'
    colvcf = 'MOD44B.006'
    colveg = 'MCD43A4.061'
    colburn = 'MCD64A1.061'
    if vernum == '1A':
        colveg = 'MCD43A4.061'
        colburn = 'MCD64A1.061'
    elif vernum == '1B':
        colveg = 'VNP43IA4.002'
        colburn = 'VNP64A1.002'
    elif vernum == '1C':
        colveg = 'VJ143IA4.002'
        colburn = 'VJ164A1.002'
    elif vernum == '1D':
        colveg = 'VJ243IA4.002'
        colburn = 'VJ264A1.002'
    elif vernum == 'NRT':
        if dtval.year < 2027:
            colveg = 'MCD43A4N.061'
        else:
            colveg = 'VJ143IA4N.002'

    kwargs['colcov'] = kwargs.get('colcov', colcov)
    kwargs['colvcf'] = kwargs.get('colvcf', colvcf)
    kwargs['colveg'] = kwargs.get('colveg', colveg)
    kwargs['colburn'] = kwargs.get('colburn', colburn)

    # MOD44B.061 excludes data above 60N, unusable
    if kwargs['colvcf'] == 'MOD44B.061':
        raise ValueError(
            'Cannot use MOD44B.061 for VCF since it is missing Arctic data'
        )

    # Fill collection headers (if unspecified)
    # ---
    output = kwargs['output']
    year = dtval.year

    # Land cover type
    colcov = kwargs['colcov']
    yearcov = min(max(year, YMINCOV), YMAXCOV)
    # Reproduce v1 bug
    if ver == '1' and year in [2022, 2023, 2024]:
        yearcov = 2022
    dircov = path.join(output, colcov, f'{yearcov}', '001')
    grancov = f'{colcov[:-4]}.A{yearcov}001.*.{colcov[-3:]}.*'
    headcov = path.join(dircov, grancov)
    kwargs['headcov'] = kwargs.get('headcov', headcov)

    # Vegetation continuous fields
    colvcf = kwargs['colvcf']
    yearvcf = min(max(year, YMINVCF), YMAXVCF)
    dirvcf = path.join(output, colvcf, f'{yearvcf}', '065')
    granvcf = f'{colvcf[:-4]}.A{yearvcf}065.*.{colvcf[-3:]}.*'
    headvcf = path.join(dirvcf, granvcf)
    kwargs['headvcf'] = kwargs.get('headvcf', headvcf)

    # Vegetation indices
    colveg = kwargs['colveg']
    jdayveg = dtval.strftime('%j')
    dirveg = path.join(output, colveg, f'{year}', jdayveg)
    granveg = f'{colveg[:-4]}.A{year}{jdayveg}.*.{colveg[-3:]}.*'
    headveg = path.join(dirveg, granveg)
    kwargs['headveg'] = kwargs.get('headveg', headveg)

    # Burned area input vars
    colburn = kwargs['colburn']
    jdayburn = dtval.replace(day=1).strftime('%j')
    dirburn = path.join(output, colburn, f'{year}', jdayburn)
    granburn = f'{colburn[:-4]}.A{year}{jdayburn}.*.{colburn[-3:]}.*'
    headburn = path.join(dirburn, granburn)
    kwargs['headburn'] = kwargs.get('headburn', headburn)

    return kwargs
