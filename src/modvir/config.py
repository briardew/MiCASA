'''
MODIS/VIIRS configuration module
'''

from datetime import datetime, timedelta
from os import path

# Land cover type variable, number of types, number of missing type
# NB: fPAR and burned area both depend on these choices
LCVAR = 'LC_Type1'
NTYPE = 18							# Including unclassified as a type
NMISS = 16							# Missing tiles assumed water

FEXT = 'nc4'							# Output file extension; see defaults['Format'] below
YMINCOV = 2001							# Minimum year for land cover
YMAXCOV = 2021							# Maximum year for land cover
YMINVCF = 2007							# Minimum year for VCF (2003-2006 are corrputed)
YMAXVCF = 2020							# Maximum year for VCF

YEAR0 = 1980							# Year that all timestamps are based on
TIME0 = datetime(YEAR0, 1, 1)					# YEAR0 in datetime format
TUNITS = 'days since ' + TIME0.strftime('%Y-%m-%d')		# Time units string

defaults = {
    # NB: NBAR data start 2000-02-16
    'dtbeg':datetime(2001, 1, 1),
    'dtend':datetime.now(),
    'ver':'NRT',
    # 0.1 deg regular grid
    'nlat':1800,
    'nlon':3600,
    'output':'.',
    # Run switches
    'force':False,
    'tidy':False,
    # Translated from args; fixme?
    'regrid':True,
    'get':True,
    'fill':True,
    # Output metadata
    'Format':'netCDF',
    'Conventions':'CF-1.9',
    'ProcessingLevel':'4',
    'institution':'NASA Goddard Space Flight Center',
    'contact':'Brad Weir <brad.weir@nasa.gov>',
}

def fillargs(dtval, **kwargs):
    '''Check and fille arguments'''

    # Set anything unspecified to default
    # ---
    for key in defaults.keys() - ['dtbeg', 'dtend']:
        kwargs[key] = kwargs.get(key, defaults[key])

    ver = kwargs['ver']
    vernum, _, domain = ver.partition('-')

    # Overwrite nlat & nlon for special domains (see geometry)
    # ---
    if domain[:5].upper() == 'CONUS':
        kwargs['nlat'] = 25*120
        kwargs['nlon'] = 60*120

    # Fill domain tag
    # ---
    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    kwargs['domtag'] = f'x{nlon}_y{nlat}'

    # Fill collection names (if unspecified)
    # ---
    # Should these be specified in defaults?
    colcov  = 'MCD12Q1.061'
    colvcf  = 'MOD44B.006'
    colveg  = 'MCD43A4.061'
    colburn = 'MCD64A1.061'
    if vernum == '1A':
        colveg  = 'MCD43A4.061'
        colburn = 'MCD64A1.061'
    elif vernum == '1B':
        colveg  = 'VNP43IA4.002'
        colburn = 'VNP64A1.002'
    elif vernum == '1C':
        colveg  = 'VJ143IA4.002'
        colburn = 'VJ164A1.002'
    elif vernum == '1D':
        colveg  = 'VJ243IA4.002'
        colburn = 'VJ264A1.002'
    elif vernum == 'NRT':
        if dtval.year < 2027:
            colveg = 'MCD43A4N.061'
        else:
            colveg = 'VJ143IA4N.002'

    kwargs['colcov']  = kwargs.get('colcov',  colcov)
    kwargs['colvcf']  = kwargs.get('colvcf',  colvcf)
    kwargs['colveg']  = kwargs.get('colveg',  colveg) 
    kwargs['colburn'] = kwargs.get('colburn', colburn)

    # MOD44B.061 excludes data above 60N, unusable
    if kwargs['colvcf'] == 'MOD44B.061':
        raise ValueError('Cannot use MOD44B.061 for VCF since it ' +
            'is missing Arctic data')

    # Fill collection dates (if unspecified)
    # ---
    output = kwargs['output']
    year = dtval.year

    # Land cover type
    colcov  = kwargs['colcov']
    yearcov = min(max(year, YMINCOV), YMAXCOV)
    dircov  = path.join(output, colcov, f'{yearcov}', '001')
    headcov = path.join(dircov, colcov[:-4] + f'.A{yearcov}001.')
    kwargs['headcov'] = kwargs.get('headcov', headcov)

    # Vegetation continuous fields
    colvcf  = kwargs['colvcf']
    yearvcf = min(max(year, YMINVCF), YMAXVCF)
    dirvcf  = path.join(output, colvcf, f'{yearvcf}', '065')
    headvcf = path.join(dirvcf, colvcf[:-4] + f'.A{yearvcf}065.')
    kwargs['headvcf'] = kwargs.get('headvcf', headvcf)

    # Vegetation indices
    colveg  = kwargs['colveg']
    jdayveg = dtval.strftime('%j')
    dirveg  = path.join(output, colveg, f'{year}', jdayveg)
    headveg = path.join(dirveg, colveg[:-4] + f'.A{year}{jdayveg}.')
    kwargs['headveg'] = kwargs.get('headveg', headveg)

    # Burned area input vars
    colburn  = kwargs['colburn']
    jdayburn = dtval.replace(day=1).strftime('%j')
    dirburn  = path.join(output, colburn, f'{year}', jdayburn)
    headburn = path.join(dirburn, colburn[:-4] + f'.A{year}{jdayburn}.')
    kwargs['headburn'] = kwargs.get('headburn', headburn)

    return kwargs
