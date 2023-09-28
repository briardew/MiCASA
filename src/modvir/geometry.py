'''
MODIS/VIIRS geometry module
'''

import numpy as np

# From https://modis-land.gsfc.nasa.gov/GCTP.html
# (also attribute buried in files: search for number)
RADIUS = 6371007.181

def edges(nlat, nlon):
    '''Short-cut for computing edge vectors'''
    late = np.linspace( -90,  90, nlat+1)
    lone = np.linspace(-180, 180, nlon+1)

    return late, lone

def centers(nlat, nlon):
    '''Short-cut for computing center vectors'''
    late, lone = edges(nlat, nlon)

    lat = 0.5*(late[1:] + late[:-1])
    lon = 0.5*(lone[1:] + lone[:-1])

    return lat, lon

def singrid(latm, lonm):
    '''Compute lat/lon mesh for MODIS sin grid'''
    latin = latm/RADIUS
    lonin = lonm/RADIUS

    LA, LO = np.meshgrid(latin, lonin)
    LO = LO/np.cos(LA)
    LA = np.rad2deg(LA)
    LO = np.rad2deg(LO)

    return LA, LO

def sinarea(latm, lonm):
    '''Compute area for MODIS sin grid'''
    latin = latm/RADIUS
    lonin = lonm/RADIUS

    LA, LO = np.meshgrid(latin, lonin)

    dlat = latin[1] - latin[0]
    dlon = lonin[1] - lonin[0]

    vlat0 = np.maximum(LA - 0.5*dlat, -0.5*np.pi)
    vlat1 = np.minimum(LA + 0.5*dlat,  0.5*np.pi)
    vlon0 = np.maximum((LO - 0.5*dlon)/np.cos(LA), -np.pi)
    vlon1 = np.minimum((LO + 0.5*dlon)/np.cos(LA),  np.pi)

    area = RADIUS**2 * abs(vlon0 - vlon1) * abs(np.sin(vlat0) - np.sin(vlat1))

    return area
