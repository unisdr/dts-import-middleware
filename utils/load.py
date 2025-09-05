import os
import logging
import requests
import json

logging.basicConfig(format='[%(levelname)s]: %(message)s', level=logging.INFO)

## (1): Load DTS_URL, DTS_KEY 
## (2): Run HUMANEFF, ASSETS, SECTORS
## (3): Run RECORDS, HUMAN, DAMAGES, DISRUPTIONS
##

def uploadAssets(dix):
    reg = dix.getRegion()[dix.region]
    # ADD ASSET
    action = "asset/add"
    headers = {"X-Auth": reg['key']}
    data = dix.getDTSassets()
    for record in data:
        response = requests.post(reg['url'] + action, headers=headers, json=record)
        if response.status_code == 201 or response.status_code == 200:
            res = response.json()['res']
            dtsid = res[0]['id']
            dix.syncDTSassets(dtsid, record[0]['nationalId'])
            print(f"Sync ASSET ID:{dtsid}) with {record[0]['nationalId']} successfully!")

def uploadRecords(dix):
    """
    Function that allows loading data into DTS
    (1) /disaster-record/add
    (2a) /human-effects/category-presence-save?recordId=e9faaa06-0e53-4ba1-b555-d444dbc02dbf
    (2b) /human-effects/save?recordId=e9faaa06-0e53-4ba1-b555-d444dbc02dbf
    (3) /sector-disaster-record-relation/add
    (4) /damage/add
    (5) /disruption/add
    """
    reg = dix.getRegion()[dix.region]
    # ADD RECORD
    act_dir = "disaster-record/add"
    act_sdr = "sector-disaster-record-relation/add"
    act_dam = "damage/add"
    act_rup = "disruption/add"
    act_hct = "human-effects/category-presence-save?recordId="
    act_hum = "human-effects/save?recordId="
    headers = {"X-Auth": reg['key']}
    data = dix.getDTSdisasterrecord()
    for record in data:
        response = requests.post(reg['url'] + act_dir, headers=headers, json=record)
        if response.status_code == 201 or response.status_code == 200:
            res = response.json()['res']
            dtsid = res[0]['id']
            print(f"RECORD (ID: {dtsid}) added successfully!")
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
                        print(f"__Sector relation added successfully. ID: {dtsid}")
                        print(response.json())
                        numrs += 1
                    else:
                        print(f"__Error adding Sector relation ID: {dtsid}: ", response.status_code)
                        print(response.text)
                if numrs > 0:
                    # ADD DAMAGES
                    for dmg in damage:
                        response = requests.post(reg['url'] + act_dam, headers=headers, json=dmg)
                        if response.status_code == 201 or response.status_code == 200:
                            print(f"____Damages values added successfully. ID: {dtsid}")
                            print(response.json())
                        else:
                            print(f"____Error adding damages value. ID: {dtsid}: ", response.status_code)
                            print(response.text)
                    # ADD DISRUPTIONS
                    for drp in disrup:
                        response = requests.post(reg['url'] + act_rup, headers=headers, json=drp)
                        if response.status_code == 201 or response.status_code == 200:
                            print(f"____Disruptions values added successfully. ID: {dtsid}")
                            print(response.json())
                        else:
                            print(f"____Error adding disruption. ID: {dtsid}: ", response.status_code)
                            print(response.text)
            else:
                print(f"__No damages or disruptions reported for ID {dtsid}")
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
                    print("____Human value added successfully!")
                    print(response.json())
                else:
                    print("____Error adding human value:", response.status_code)
                    print(response.text)
        else:
            print("Error adding RECORD:", response.status_code)
            print(response.text)
    logging.info('Upload records to DTS in process....')

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
