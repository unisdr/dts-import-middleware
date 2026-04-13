import os
import logging
import requests
import json
import time

logging.basicConfig(format='[%(levelname)s]: %(message)s', level=logging.INFO)

## (1): Load DTS_URL, DTS_KEY 
## (2): Run HUMANEFF, ASSETS, SECTORS
## (3): Run RECORDS, HUMAN, DAMAGES, DISRUPTIONS

## In order of ocurrence: Upload Geography
def exportGeoFiles(dix):
    path = "/tmp/dts/" + dix.region + "/"
    try:
        os.mkdir(path)
        os.mkdir(path + "geojson/")
        print(f"Directory '{path}' created successfully.")
        dix.exportGeo(path)
    except FileExistsError:
        print(f"Directory '{path}' already exists.")
    except Exception as e:
        print(f"An error occurred: {e}")

def syncGeography(dix):
    reg = dix.getRegion()[dix.region]
    action = "division/list?page="
    headers = {"X-Auth": reg['key']}
    try:
        page = 1
        while True:
            response = requests.get(reg['url'] + action + str(page), headers=headers)
            data = response.json()['data']
            pags = data['pagination']
            total = pags['totalItems']
            onpage = pags['pageSize']
            print(f"Sync IDs of Geography items: {page*onpage} of {total}")
            for items in data['items']:
                dix.setDTSgeography(items['id'], items['nationalId'])
            if ((page * onpage) <= total ):
                page += 1
            else:
                break
    except requests.exceptions.HTTPError as e:
        print(f"HTTP Error: {e}")
    except requests.exceptions.RequestException as e:
        print(f"Request Error: {e}")
    except requests.exceptions.JSONDecodeError:
        print("Error: Could not decode JSON from the response.")

def uploadAssets(dix):
    reg = dix.getRegion()[dix.region]
    # ADD ASSET
    action = "asset/add"
    headers = {"X-Auth": reg['key']}
    data = dix.getDTSnewassets()
    for record in data:
        response = requests.post(reg['url'] + action, headers=headers, json=record)
        print(response)
        if response.status_code == 201 or response.status_code == 200:
            res = response.json()['res']
            dtsid = res[0]['id']
            print(f"Sync ASSET ID:{dtsid}) with {record[0]['nationalId']} successfully!")
        else:
            print(f"No sync ASSET with record: {record}")

def syncAssets(dix):
    reg = dix.getRegion()[dix.region]
    action = "asset/list?page="
    headers = {"X-Auth": reg['key']}
    try:
        page = 1
        while True:
            response = requests.get(reg['url'] + action + str(page), headers=headers)
            data = response.json()['data']
            pags = data['pagination']
            total = pags['totalItems']
            onpage = pags['pageSize']
            print(f"Sync IDs of Assets: {page*onpage} of {total}")
            for items in data['items']:
                dix.setDTSassets(items['id'], items['nationalId'])
            if ((page * onpage) <= total ):
                page += 1
            else:
                break
    except requests.exceptions.HTTPError as e:
        print(f"HTTP Error: {e}")
    except requests.exceptions.RequestException as e:
        print(f"Request Error: {e}")
    except requests.exceptions.JSONDecodeError:
        print("Error: Could not decode JSON from the response.")

def uploadRecords(dix):
    """
    Function that allows loading data into DTS
    (1) /disaster-record/upsert
    (2a) /human-effects/category-presence-save?recordId=e9faaa06-0e53-4ba1-b555-d444dbc02dbf
    (2b) /human-effects/save?recordId=e9faaa06-0e53-4ba1-b555-d444dbc02dbf
    (3) /sector-disaster-record-relation/add
    (4) /damage/add
    (5) /disruption/add
    """
    reg = dix.getRegion()[dix.region]
    # ADD RECORD
    act_dir = "disaster-record/upsert"
    act_sdr = "sector-disaster-record-relation/add"
    act_dam = "damage/add"
    act_rup = "disruption/add"
    act_hct = "human-effects/category-presence-save?recordId="
    act_hum = "human-effects/save?recordId="
    headers = {"X-Auth": reg['key']}
    data = dix.getDTSdisasterrecord()
    max_retries = 3
    for record in data:
        dtsid = None
        for attempt in range(max_retries):
            log = ""
            try:
                response = requests.post(reg['url'] + act_dir, headers=headers, json=record, timeout=10)
                response.raise_for_status()
                res = response.json()['res']
                log += str(res) +"\n"
                log += f"/{record}/\n"
                if (res[0]['ok']):
                    dtsid = res[0]['id']
                    dix.setDTSdisasterrecord(record[0]["legacyData"]["DIID"], dtsid)
                    log += f"RECORD (ID: {dtsid}) added successfully!\n"
                    orgid = record[0]["legacyData"]
                    damage = dix.getDTSdamages(dtsid, orgid['DIID'])
                    disrup = dix.getDTSdisruptions(dtsid, orgid['DIID'])
                    if damage or disrup:
                        # ADD RECORD-SECTOR Relation
                        sector = dix.getDTSsectors(dtsid, orgid['DIID'])
                        numrs = 0
                        for sect in sector:
                            response = requests.post(reg['url'] + act_sdr, headers=headers, json=sect)
                            if response.status_code == 201 or response.status_code == 200:
                                res = response.json()
                                if (res['ok']):
                                    log += f"__Sector relation added successfully. Sector ID: {sect[0]['sectorId']}\n"
                                    numrs += 1
                                else:
                                    log += f"__Sector relation error: {json.dumps(sect)}\n"
                                    log += f"/{res}/\n"
                            else:
                                log += f"__Error adding relation SectorID: {sect[0]['sectorId']}: Status {response.status_code}\n"
                                log += response.text +"\n"
                                log += f"__Using:: {sect}\n"
                        if numrs > 0:
                            # ADD DAMAGES
                            for dmg in damage:
                                response = requests.post(reg['url'] + act_dam, headers=headers, json=dmg)
                                if response.status_code == 201 or response.status_code == 200:
                                    res = response.json()
                                    if (res['ok']):
                                        log += f"____Damages values added successfully. Asset ID: {dmg[0]['assetId']}\n"
                                    else:
                                        log += f"____Damages values with errors: {response.json()}\n"
                                else:
                                    log += f"____Error adding damages value. AssetID: {dmg[0]['assetId']}: {response.status_code}\n"
                                    log += response.text + "\n"
                                    log += f"____Using:: {dmg}\n"
                            # ADD DISRUPTIONS
                            for drp in disrup:
                                response = requests.post(reg['url'] + act_rup, headers=headers, json=drp)
                                if response.status_code == 201 or response.status_code == 200:
                                    res = response.json()
                                    if (res['ok']):
                                        log += f"____Disruptions values added successfully. SectorID: {drp[0]['sectorId']}\n"
                                    else:
                                        log += f"____Disruptions values with errors: {response.json()}\n"
                                        log += response.json()
                                else:
                                    log += f"____Error adding disruption. SectorID: {drp[0]['sectorId']}: {response.status_code}\n"
                                    log += response.text + "\n"
                                    log += f"____Using:: {drp}\n"
                    else:
                        log += f"__No damages or disruptions reported for RecordID {dtsid}\n"
                    # ADD HUMAN Values
                    human = dix.getDTSHuman(orgid['DIID'])
                    for key, value in human.items():
                        newrows = {}
                        for i in range(len(value)):
                            if i > 0:
                                newrows[f"_temp{i}"] = value[i]
                        hmn = {"table": key, "columns": value[0], "data": {"updates":[], "deletes":[], "newRows": newrows } }
                        response = requests.post(reg['url'] + act_hum + dtsid, headers=headers, json=hmn)
                        if response.status_code == 201 or response.status_code == 200:
                            res = response.json()
                            if (res['ok']):
                                log += f"____Human value added successfully. Table: {hmn['table']}\n"
                            else:
                                log += f"____Human value with errors: {response.json()}\n"
                        else:
                            log += f"____Error adding human value:{response.status_code}\n"
                            log += response.text + "\n"
                            log += f"____Using:: {hmn}\n"
                else:
                    log += f"Record value with errors: {response.json()}\n"
                ##dix.insertLog(orgid['DIID'], log)
                print(log)
                break
            except requests.exceptions.RequestException as e:
                print(f"Request error: {e}")
            except requests.exceptions.JSONDecodeError as e:
                print(f"JSON Decode error: {e}")
                print(f"Raw response content: {response.text}")
            except requests.exceptions.ConnectionError as e:
                print(f"Attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt) # Exponential backoff
                    continue
                else:
                    print("Max retries exceeded. Giving up.")
                    raise
        print("****")
    logging.info('Upload records to DTS in process....')

def deleteDisrecords(dix):
    reg = dix.getRegion()[dix.region]
    # ADD ASSET
    action = "disaster-record/list?page="
    headers = {"X-Auth": reg['key']}
    try:
        i = 0
        page = 1
        while True:
            response = requests.get(reg['url'] + action + str(page), headers=headers)
            data = response.json()['data']
            pags = data['pagination']
            if page == 1:
                total = pags['totalItems']
            onpage = pags['pageSize']
            for items in data['items']:
                i += 1
                response = requests.delete(reg['url'] + "disaster-record/delete/" + items['id'], headers=headers)
                print(f"Delete ID [{i}/{total}]: {items['id']}: {response.json()}")
                dix.deleteRecords(items['id'])
            if ((page * onpage) <= total ):
                page += 1
            else:
                break
    except requests.exceptions.HTTPError as e:
        print(f"HTTP Error: {e}")
    except requests.exceptions.RequestException as e:
        print(f"Request Error: {e}")
    except requests.exceptions.JSONDecodeError:
        print("Error: Could not decode JSON from the response.")

"""
def testRecords(dix):
    reg = dix.getRegion()[dix.region]
    data = dix.getDTSdisasterrecord()
    for record in data:
        orgid = record[0]["legacyData"]
        print("RECORD " + orgid['DIID'])
        human = dix.getDTSHuman(orgid['DIID'])
        for key, value in human.items():
            newrows = {}
            for i in range(len(value)):
                if i > 0:
                    newrows[f"_temp{i}"] = value[i]
            #nr = ','.join("'{}': {}".format(k,v) for k,v in newrows.items())
            hmn = {"table": key, "columns": value[0], "data": {"updates":[], "deletes":[], "newRows": newrows } }
            #hmn = {"table": key, "columns": value[0], "data": {"updates":[], "deletes":[], "newRows": {dict(k = v) for k,v in newrows.items()} } }
            print(hmn)
"""   