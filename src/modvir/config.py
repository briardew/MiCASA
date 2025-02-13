'''
MODIS/VIIRS configuration module
'''

from datetime import datetime

# NB: NBAR data start 2000-02-16
defaults = {
    'data': 'data',
    'date0': datetime(2001, 1, 1),
    'dateF': datetime.now(),
    # 0.1 deg regular grid
    'nlat': 1800,
    'nlon': 3600,
    # run switches (values currently ignored in __main__)
    'repro': False,
    'nrt': False,
    'tidy': False,
    # translated from inputs; fixme?
    'regrid': True,
    'get': True,
    'fill': True,
}

# Land cover type variable, number of types, number of missing type
# NB: fPAR and burned area both depend on these choices
LCVAR = 'LC_Type1'
NTYPE = 18					# Including unclassified as a type
NMISS = 16					# Missing tiles assumed water

YMAXCOV = 2021					# Maximum year for land cover
YMAXVCF = 2020					# Maximum year for VCF

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

    return kwargs

def check_cols(date, **kwargs):
    '''Check and fill collection tags'''

    # Shouldn't these be specified in defaults?
    colcov  = kwargs.get('colcov',  'MCD12Q1.061')
    colvcf  = kwargs.get('colvcf',  'MOD44B.006')
    colveg  = kwargs.get('colveg',  'MCD43A4.061')
    colburn = kwargs.get('colburn', 'MCD64A1.061')

    # Brutal hack, needs better treatment (not working anyways)
    if 2025 < date.year:
        colcov  = 'VNP12Q1.001'
        colvcf  = 'VNP44B.001'
        colveg  = 'VNP43IA4.002'
        colburn = 'VNP64A1.002'

    # Needs better treatment
    if kwargs.get('nrt', defaults['nrt']): colveg = 'MCD43A4N.061'

    # MOD44B.061 excludes data above 60N, unusable
    if colvcf == 'MOD44B.061':
        raise ValueError('Cannot use ' + colvcf + ' for VCF since it ' +
            'is missing Arctic data')

    kwargs['colcov']  = colcov
    kwargs['colvcf']  = colvcf
    kwargs['colveg']  = colveg
    kwargs['colburn'] = colburn

    return kwargs
