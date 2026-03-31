'''
MODIS/VIIRS configuration module
'''

from datetime import datetime

# Land cover type variable, number of types, number of missing type
# NB: fPAR and burned area both depend on these choices
LCVAR = 'LC_Type1'
NTYPE = 18					# Including unclassified as a type
NMISS = 16					# Missing tiles assumed water

FEXT = 'nc4'					# Output file extension; see defaults['Format'] below
YMINCOV = 2001					# Minimum year for land cover
YMAXCOV = 2021					# Maximum year for land cover
YMINVCF = 2007					# Minimum year for VCF (2003-2006 are corrputed)
YMAXVCF = 2020					# Maximum year for VCF

defaults = {
    'output':'.',
    # NB: NBAR data start 2000-02-16
    'date0':datetime(2001, 1, 1),
    'dateF':datetime.now(),
    # 0.1 deg regular grid
    # This should be transitioned to lats and lons
    'nlat':1800,
    'nlon':3600,
    'ver':'1',
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

def check_args(**kwargs):
    '''Argument error check and standardization'''

    # Check dates make sense
    date0 = kwargs.get('date0', defaults['date0'])
    dateF = kwargs.get('dateF', defaults['dateF'])
    if dateF < date0:
        raise ValueError('Begin date (' + date0.strftime('%Y-%m-%d') + ')' +
            ' later than end date (' + dateF.strftime('%Y-%m-%d') + ')')

    # Set anything missing to default
    for key in defaults:
        kwargs[key] = kwargs.get(key, defaults[key])

    # Set spatial attributes (needs to be generalized)
    nlat = kwargs['nlat']
    nlon = kwargs['nlon']
    kwargs['Resolution'] = (f'{round(180/nlat,3)} degree x ' +
        f'{round(360/nlon,3)} degree')
    kwargs['NorthernmostLatiude']  = '90.0'
    kwargs['WesternmostLongitude'] = '-180.0'
    kwargs['SouthernmostLatitude'] = '-90.0'
    kwargs['EasternmostLongitude'] = '180.0'

    return kwargs

def check_cols(date, **kwargs):
    '''Check and fill collection tags'''

    ver = kwargs.get('ver', defaults['ver'])

    # Should these be specified in defaults?
    colcovdef  = 'MCD12Q1.061'
    colvcfdef  = 'MOD44B.006'
    colvegdef  = 'MCD43A4.061'
    colburndef = 'MCD64A1.061'
    if ver == '1A':
        colvegdef  = 'MCD43A4.061'
        colburndef = 'MCD64A1.061'
    elif ver == '1B':
        colvegdef  = 'VNP43IA4.002'
        colburndef = 'VNP64A1.002'
    elif ver == '1C':
        colvegdef  = 'VJ143IA4.002'
        colburndef = 'VJ164A1.002'
    elif ver == '1D':
        colvegdef  = 'VJ243IA4.002'
        colburndef = 'VJ264A1.002'
    elif ver == 'NRT':
        if date.year < 2027:
            colvegdef = 'MCD43A4N.061'
        else:
            colvegdef = 'VJ143IA4N.002'

    kwargs['colcov']  = kwargs.get('colcov',  colcovdef)
    kwargs['colvcf']  = kwargs.get('colvcf',  colvcfdef)
    kwargs['colveg']  = kwargs.get('colveg',  colvegdef) 
    kwargs['colburn'] = kwargs.get('colburn', colburndef)

    # MOD44B.061 excludes data above 60N, unusable
    if kwargs['colvcf'] == 'MOD44B.061':
        raise ValueError('Cannot use MOD44B.061 for VCF since it ' +
            'is missing Arctic data')

    return kwargs
