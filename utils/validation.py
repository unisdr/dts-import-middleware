import os
import asyncio

## Get the list of fields and Insert/update DIX Records, Human, Damages and Disruptions 
def transform_datacards(dix, cards):
    # Check for empty values
    if cards.isnull().values.any():
        raise Exception('Datacards Null values!')
    else:
        # get the values from RECORD
        for index, val in cards.items():
            dix.insertDIXRecord(index, val)
            # commit each RECORD and their EFFECTS to the database
            dix.commitdb()

## Get the list of fields and Insert/update DIX Records:: GEO 
def transform_geo(dix, geo):
    # GEOGRAPHY Check for empty values
    if geo.isnull().values.any():
        print('Geography Null values!')
    else:
        # set National Level
        dix.setGeoCountry()
        # get the values from LAYERS and LAYER_DATA
        shp = []
        for index, val in geo.items():
            dix.setGeography(index, val)
            if len(val['items'])>0:
                if isinstance(val['filename'],str):
                    file = val['filename'].split("/")[-1]
                    shp.append({"level": index, "file": file, 'colname': val['col_name'], 'colcode': val['col_code']})
        dix.downloadDIMaps(shp)
        #dix.downloadGADMaps()

## Get the list of fields and Insert/update DIX Records:: EFF
def transform_eff(dix, eff):
    # EFFECTS Check for empty values
    if eff.isnull().values.any():
        print('Effects Null values!')
    else:
        # get the values from HUMANEFF, SECTORS, ASSETS
        for index, val in eff.items():
            asyncio.run(dix.setEffects(index, val))
        dix.commitdb()

## Get the list of fields and Insert/update DIX Records:: GEO 
def transform_hzd(dix, hzd):
    # HAZARDS Check for empty values
    if hzd.isnull().values.any():
        print('Hazards Null values!')
    else:
        # update the rules from HIPS
        for index, val in hzd.items():
            asyncio.run(dix.setHIPsRules(index, val))
        dix.commitdb()
