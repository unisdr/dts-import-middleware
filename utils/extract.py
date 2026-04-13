#import os
import pandas as pd
import requests
import logging

# Logger initialization
logging.basicConfig(format='[%(levelname)s]: %(message)s', level=logging.INFO)

##  Get the API endpoint from DesInventar for datacards
##  -> add new rows for HUMANEFF, SECTORS, ASSETS. Use HIPS setting event_rules:: =hzd_label, Geography List 
##     and List of Effect (predefined by DI and by the Region) 
def extract_datacards(url, head, reg, nextpage):
    cty = reg.lower()
    if nextpage != "nonext":
        action = f"datacards?country={cty}&page={nextpage}"
        logging.info(f"[{reg}]: {url}{action}")
        try:
            response = requests.get(url + action, headers=head)
            response.raise_for_status()
            return pd.DataFrame(response.json())
        except Exception as e:
            print(f"Error fetching DATACARDS JSON from URL: {e}")
    return pd.DataFrame()
    

# Get the API endpoint from DesInventar for Geography List
def extract_geo(dix, url, head, reg):
    logging.info(f"[{reg}]: Setup DB: Geography")
    cty = reg.lower()
    ### Prepare the headers ###
    action = f"geographylist?country={cty}"
    logging.info(f"[{reg}]: {url}{action}")
    try:
        response = requests.get(url + action, headers=head)
        response.raise_for_status()
        geog_df = pd.DataFrame(response.json())
        return geog_df['geo']
    except Exception as e:
        print(f"Error fetching GEOGRAPHY JSON from URL: {e}")
    return pd.DataFrame()

# Get the API endpoint from DesInventar for Effects List
def extract_effects(dix, url, head, reg):
    logging.info(f"[{reg}]: Setup DB: Effects")
    cty = reg.lower()
    ### Prepare the headers ###
    action = f"effectslist?country={cty}"
    logging.info(f"[{reg}]: {url}{action}")
    try:
        response = requests.get(url + action, headers=head)
        response.raise_for_status()
        effe_df = pd.DataFrame(response.json())
        return effe_df['effects']
    except Exception as e:
        print(f"Error fetching EFFECTS JSON from URL: {e}")
    return pd.DataFrame()

# Get the API endpoint from DesInventar for List of Hazards
def extract_hazards(dix, url, head, reg):
    logging.info(f"[{reg}]: Setup DB: Hazards")
    cty = reg.lower()
    ### Prepare the headers ###
    action = f"hazardslist?country={cty}"
    logging.info(f"[{reg}]: {url}{action}")
    try:
        response = requests.get(url + action, headers=head)
        response.raise_for_status()
        haza_df = pd.DataFrame(response.json())
        return haza_df['hazards'] # has 'events' and 'causes'
    except Exception as e:
        print(f"Error fetching HAZARDS JSON from URL: {e}")
    return pd.DataFrame()
