'''
MODIS/VIIRS configuration module
'''

from datetime import datetime

# NB: NDVI data start 2000-02-16
defaults = {
    'data': 'data',
    'date0': datetime(2001, 1, 1),
    'dateF': datetime.now(),
    # 0.1 deg regular grid
    'nlat': 1800,
    'nlon': 3600,
    # run switches
    'get': True,
    'regrid': True,
    'fill': True,
    'repro': False,
    'rmcol': False,
}

# Land cover type variable, number of types, number of missing type
# NB: fPAR and burned area both depend on these choices
LCVAR = 'LC_Type1'
NTYPE = 18 # Including unclassified as a type
NMISS = 16 # Missing tiles assumed water

# Year bounds on required products
# Persistence used outside this range; worth revisiting
BEGYEARCOV = 2001
ENDYEARCOV = datetime.now().year - 2
BEGYEARVCF = 2000
ENDYEARVCF = datetime.now().year - 2

def check_args(date0, dateF, **kwargs):
    '''Argument error check and standardization'''

    # Check dates make sense
    if dateF < date0:
        raise ValueError('Begin date (' + date0.strftime('%Y-%m-%d') + ')' +
            ' later than end date (' + dateF.strftime('%Y-%m-%d') + ')')

    # Set anything missing to default
    for key in defaults:
        kwargs[key] = kwargs.get(key, defaults[key])

    return kwargs

def check_cols(date, **kwargs):
    '''Check and fill collection tags'''

    colcov = kwargs.get('colcov', None)
    colvcf = kwargs.get('colvcf', None)
    colveg = kwargs.get('colveg', None)
    colburn = kwargs.get('colburn', None)

    if colcov is None: colcov = 'MCD12Q1.061'
    if colvcf is None: colvcf = 'MOD44B.061'
    if colveg is None: colveg = 'MCD43A4.061'
    if colburn is None: colburn = 'MCD64A1.061'

    if 2025 < date.year:
        colcov = 'VNP12Q1.001'
        colvcf = 'VNP44B.001'
        colveg = 'VNP43IA4.001'
        colburn = 'VNP64A1.001'

    kwargs['colcov'] = colcov
    kwargs['colvcf'] = colvcf
    kwargs['colveg'] = colveg
    kwargs['colburn'] = colburn

    return kwargs
