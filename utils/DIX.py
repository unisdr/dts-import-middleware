import psycopg2
import hashlib
import json
from datetime import datetime, timedelta
from googletrans import Translator
import pandas as pd
from psycopg2 import errors

class DIX:
    """DIX Regions administration"""
    regs = {}
    region = None
    conn = None
    cur = None
    humaneff = {}
    assets = {}
    sectors = {}
    jso = "" # Current json string processed
    option = False

    def __init__(self, region, opt):
        """Initializes a Region Object."""
        DIX.region = region
        DIX.option = opt
        # Database connection
        DIX.conn = psycopg2.connect(host="localhost", database="DIX", user="postgres", password="postgres")
        DIX.cur = DIX.conn.cursor()
        try:
            with DIX.conn:
                qry = "SELECT region_id, name, lang, export_url, export_apikey, tags FROM region WHERE sources='DI.net'"
                if (len(DIX.region) != 0):
                    qry = f"{qry} AND region_id='{DIX.region}'"
                DIX.cur.execute(qry)
                for row in DIX.cur.fetchall():
                    DIX.regs[row[0]] = {'name': row[1], 'lang': row[2], 'url': row[3], 'key': row[4], 'tags': row[5]}
        except Exception as e:
            print(f"Error: {e}")
        # getting list of humaneff, assets ans sectors for the country
        self.getHumanEff()
        self.getAssets()
        self.getSectors()

    def getRegion(self):
        return DIX.regs

    ## (step 1) Process for table RECORDS::
    ## rec_uuid, reg_id, hzd_id, serial, year, month, day, sources,comments, card_usereff, status, created, updated, card_causevent, 
    ## eff_econusd, eff_econlcu, card_other, card_withothersector, card_geolocation, card_version
    def insertDIXRecord(self, index, val):
        DIX.jso = json.dumps(val)
        # Generate Record data version
        ver = hashlib.md5(DIX.jso.encode()).hexdigest()
        try:
            # CREATE or UPDATE only changed RECORDS based on MD5 card_version field ;)
            sqlrec = f"""INSERT INTO records as r (rec_uuid,reg_id,serial,year,month,day,duration,sources,eff_econusd,eff_econlcu,eff_other,
                eff_withother,card_version,status,created) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) ON CONFLICT (rec_uuid) DO 
                UPDATE SET serial=EXCLUDED.serial, year=EXCLUDED.year, month=EXCLUDED.month, day=EXCLUDED.day, duration=EXCLUDED.duration, 
                card_version=EXCLUDED.card_version, updated='{datetime.datetime.now()}' WHERE r.card_version<>'{ver}' and r.rec_uuid='{index}';"""
            rec = (index, DIX.region, val["rec_serial"], val["eff_year"], val["eff_month"], val["eff_day"], val["hzd_eventduration"], val["rec_sources"],
                val["eff_lossesusd"], val["eff_losseslcu"], val["eff_others"], val["eff_withothers"], ver, 'published', datetime.datetime.now())
            DIX.cur.execute(sqlrec, rec)
            # Get Geo ID based on Region and codification
            geo = self.getGeo(val['geo_cod0'], val['geo_cod1'], val['geo_cod2'])
            place = "" if val['geo_place'] is None else f"""place: {val['geo_place'].replace("'", "")}"""
            try:
                # Create record - geography relationship
                DIX.cur.execute(f"""INSERT INTO georecord (record_id, geogra_id, laytype_id, location) VALUES ('{index}', '{geo}', 'admin', '{place}') 
                ON CONFLICT (record_id, geogra_id) DO NOTHING;""")
                self.commitdb()
            except errors.ForeignKeyViolation as e:
                print(f"Geo-Record ({geo})({index}). Error: {e}")
            # Get the HIP Id based on Event-Cause
            hzd = self.getHips(val['hzd_label'], val['hzd_event'], val['hzd_cause'])
            info = f"""event:{"" if val['hzd_event'] is None else val['hzd_event'].replace("'","")},cause:{"" if val['hzd_cause'] is None else val['hzd_cause'].replace("'","")},
                magnitude={"" if val['hzd_eventmagnitude'] is None else val['hzd_eventmagnitude'].replace("'","")}"""
            try:
                # Create record - HIPS relationship
                DIX.cur.execute(f"""INSERT INTO groupsrecord (record_id, grp_id, grp_info) VALUES ('{index}', '{hzd}', '{info}') 
                ON CONFLICT (record_id, grp_id) DO NOTHING;""")
                self.commitdb()
            except errors.ForeignKeyViolation as e:
                print(f"HIPS-Record ({hzd})({index}). Error: {e}")
            # Create record - human relationship
            ## (2) Using rec_uuid, process for table HUMAN::record_id, humaneff_id, value, witheffect
            try:
                sqlhum = f"""INSERT INTO human as h (record_id, humaneff_id, value, withaffect) VALUES (%s, %s, %s, %s) 
                ON CONFLICT (record_id, humaneff_id) DO NOTHING;"""
                for ky, v in DIX.humaneff.items():
                    if v['qt'] in val.keys():
                        ql = False
                        if 'ql' in v.keys() and val[v['ql']] is True:
                            ql = True
                        if isinstance(val[v['qt']], int) > 0 or ql:
                            hum = (index, ky, val[v['qt']], True)
                            DIX.cur.execute(sqlhum, hum)
                self.commitdb()
            except errors.ForeignKeyViolation as e:
                print(f"Human-Record ({index}). Error: {e}")
            # Create record - damages relationship
            ## (3) Using rec_uuid, process for table DAMAGES::record_id, asset_id, total, destroyed, damaged, economic, withanyaff
            try:
                sqldde = f"""INSERT INTO damages as m (record_id, asset_id, total, destroyed, damaged, economic, withanyaff) VALUES 
                (%s, %s, %s, %s, %s, %s, %s) ON CONFLICT (record_id, asset_id) DO NOTHING;"""
                for ky, v in DIX.assets.items():
                    flg = False
                    tot = dmg = dst = eco = None
                    if 'tot' in v.keys() and v['tot'] in val.keys() and isinstance(val[v['tot']], int) and val[v['tot']] > 0:
                        tot = val[v['tot']]
                        flg = True
                    if 'dmg' in v.keys() and v['dmg'] in val.keys() and isinstance(val[v['dmg']], int) and val[v['dmg']] > 0:
                        dmg = val[v['dmg']]
                        flg = True
                    if 'dst' in v.keys() and v['dst'] in val.keys() and isinstance(val[v['dst']], int) and val[v['dst']] > 0:
                        dst = val[v['dst']]
                        flg = True
                    if 'eco' in v.keys() and v['eco'] in val.keys() and isinstance(val[v['eco']], int) and val[v['eco']] > 0:
                        eco = val[v['eco']]
                        flg = True
                    if flg:
                        dde = (index, ky, tot, dmg, dst, eco, True)
                        DIX.cur.execute(sqldde, dde)
                self.commitdb()
            except errors.ForeignKeyViolation as e:
                print(f"Damages-Record ({index}). Error: {e}")
            # Create record - disruptions relationship
            ## (4) Using rec_uuid, process for table DISRUPTIONS::record_id, sector_id, disruptnum
            try:
                sqldrp = f"""INSERT INTO disruptions as d (record_id, sector_id, disruptnum) VALUES (%s, %s, %s) ON CONFLICT (record_id, sector_id) DO NOTHING;"""
                for ky, v in DIX.sectors.items():
                    if v in val.keys():
                        if val[v] > 0:
                            drp = (index, ky, val[v])
                            DIX.cur.execute(sqldrp, drp)
                self.commitdb()
            except errors.ForeignKeyViolation as e:
                print(f"Disruptions-Record ({index}). Error: {e}")
        except psycopg2.Error as e:
            print(f"Database Error: {e}")
            DIX.conn.rollback()

    ## (step 1a) Get HIPs ID using Region, Event and Cause::
    def getHips(self, label, event, cause):
        eve = event.replace("'", "")
        cau = "" if cause is None else cause.replace("'", "")
        DIX.cur.execute(f"""SELECT id FROM groups WHERE cat_id='hips2021' AND (join_rules LIKE '%={label.strip()}%' OR join_rules LIKE '%{DIX.region}={label.strip()}%'
            OR join_rules LIKE '%={eve.strip()}%' OR join_rules LIKE '%{DIX.region}={eve.strip()}%' OR join_rules LIKE '%?{eve}>%{cau}%');""")
        row = DIX.cur.fetchone()
        if row:
            return row[0]
        else:
            return "OTHER"

    # list of Humaneffects 
    def getHumanEff(self):
        DIX.cur.execute(f"SELECT h.id, h.codeqt, h.codeql FROM humaneff h, regeffects e WHERE e.reg_id='{DIX.region}' and e.humaneff_id=h.id")
        for row in DIX.cur.fetchall():
            q = {}
            q['qt'] = row[1][1:]
            if row[2]:
                q['ql'] = row[2][1:]
            DIX.humaneff[row[0]] = q
        #print(humaneff)

    # list of Assets
    def getAssets(self):
        DIX.cur.execute(f"SELECT a.id, a.codeqt_tot, a.codeqt_dst, a.codeqt_dmg, a.codeqt_eco FROM assets a, regeffects e WHERE e.reg_id='{DIX.region}' and e.asset_id=a.id")
        for row in DIX.cur.fetchall():
            q = {}
            if row[1]:
                q['tot'] = row[1][1:]
            if row[2]:
                q['dst'] = row[2][1:]
            if row[3]:
                q['dmg'] = row[3][1:]
            if row[4]:
                q['eco'] = row[4][1:]
            DIX.assets[row[0]] = q
        #print(assets)

    # list of Sectors
    def getSectors(self):
        DIX.cur.execute(f"SELECT s.id, s.codeql FROM sectors s, regeffects e WHERE e.reg_id='{DIX.region}' and e.sector_id=s.id")
        for row in DIX.cur.fetchall():
            if row[1]:
                DIX.sectors[row[0]] = row[1][1:]
        #print(sectors)

    async def setEffects(self, index, val):
        excl = ["eff_lossesusd", "eff_losseslcu", "eff_others", "eff_withothers"] 
        # ASSETS
        DIX.cur.execute(f"""SELECT id, codeqt_tot, codeqt_dst, codeqt_dmg, codeqt_eco FROM assets WHERE 
            codeqt_tot like '%{index}%' OR codeqt_dst like '%{index}%' OR codeqt_dmg like '%{index}%' OR codeqt_eco like '%{index}%';""")
        row = DIX.cur.fetchone()
        # New relation Region - Effect
        if row:
            if isinstance(row[1], str) or isinstance(row[2], str) or isinstance(row[3], str) or isinstance(row[4], str):
                # Insert new Asset if not exists 
                DIX.cur.execute(f"SELECT asset_id FROM regeffects WHERE reg_id='{DIX.region}' AND asset_id='{index}';")
                row1 = DIX.cur.fetchone()
                if not row1:
                    qry_a = f"""INSERT INTO regeffects(reg_id, asset_id) VALUES ('{DIX.region}', '{row[0]}')"""
                    DIX.cur.execute(qry_a)
                    #print(qry_a)
        else:
            # HUMAN EFFECTS
            DIX.cur.execute(f"SELECT id, codeqt, codeql FROM humaneff WHERE codeqt like '%{index}%' OR codeql like '%{index}%';")
            row = DIX.cur.fetchone()
            # New relation Region - Effect
            if row:
                if isinstance(row[1], str) or isinstance(row[2], str):
                    DIX.cur.execute(f"SELECT humaneff_id FROM regeffects WHERE reg_id='{DIX.region}' AND humaneff_id='{index}';")
                    row1 = DIX.cur.fetchone()
                    if not row1:
                        qry_h = f"""INSERT INTO regeffects(reg_id, humaneff_id) VALUES ('{DIX.region}', '{row[0]}')"""
                        DIX.cur.execute(qry_h)
                        #print(qry_h)
            else:
                # SECTORS
                DIX.cur.execute(f"SELECT id, codeql FROM sectors WHERE codeql like '%{index}%';")
                row = DIX.cur.fetchone()
                # New relation Region - Effect
                if row:
                    if isinstance(row[1], str):
                        DIX.cur.execute(f"SELECT sector_id FROM regeffects WHERE reg_id='{DIX.region}' AND sector_id='{index}';")
                        row1 = DIX.cur.fetchone()
                        if not row1:
                            qry_s = f"""INSERT INTO regeffects(reg_id, sector_id) VALUES ('{DIX.region}', '{row[0]}')"""
                            DIX.cur.execute(qry_s)
                            #print(qry_s)
                else:
                    if not index in excl:
                        description = "" if val['name'] is None else val['name'].replace("'", "") + ": " + "" if val['description'] is None else val['description'].replace("'","")
                        if DIX.regs[DIX.region]['lang'] != 'en':
                            # Translate and autoclassification of Effects names
                            x = await self.translate_text(description.lower())
                        else:
                            x = description.lower()
                        if x.find('famil') != -1 or x.find('child') != -1 or x.find('person') != -1 or x.find('people') != -1:
                            qry_h = f"""INSERT INTO humaneff(id, description, type, codeqt) VALUES ('{DIX.region}={index}', '{description}', 
                                'otherhuman', '={index}') ON CONFLICT (id) DO NOTHING"""
                            DIX.cur.execute(qry_h)
                            #print(qry_h)
                            qry2_h = f"""INSERT INTO regeffects(reg_id, humaneff_id) VALUES ('{DIX.region}', '{DIX.region}={index}')"""
                            DIX.cur.execute(qry2_h)
                            #print(qry2_h)
                        else:
                            name = "" if val['name'] is None else val['name'].replace("'", "")
                            description = "" if val['description'] is None else val['description'].replace("'","")
                            measure = "" if val['fieldtype'] is None else val['fieldtype'].replace("'", "")
                            code = 'codeqt_tot'
                            if measure == 'currency' or measure == 'float':
                                code = 'codeqt_eco'
                            elif measure == 'integer':
                                measure = 'units'
                            qry_a = f"""INSERT INTO assets(id, {code}, measure, name, description, sector_id) VALUES ('{DIX.region}={index}', '={index}', '{measure}', 
                                '{name}', '{description}', 'unknown') ON CONFLICT (id) DO NOTHING"""
                            DIX.cur.execute(qry_a)
                            #print(qry_a)
                            qry2_a = f"""INSERT INTO regeffects(reg_id, asset_id) VALUES ('{DIX.region}', '{DIX.region}={index}')"""
                            DIX.cur.execute(qry2_a)
                            #print(qry2_a)

    async def translate_text(self, text, dest_language='en', src_language='auto'):
        async with Translator() as translator:
            result = await translator.translate(text, dest=dest_language, src=src_language)
            return result.text

    async def setHIPsRules(self, index, val):
        #print(index, val)
        label = index.replace("'", " ")
        DIX.cur.execute(f"SELECT id,fullname FROM groups WHERE cat_id='hips2021' AND join_rules LIKE '%={label}%' OR join_rules LIKE '%?{label}>%' OR join_rules LIKE '%{DIX.region}={index}%'")
        row = DIX.cur.fetchone()
        # New event not classified.
        if not row:
            if DIX.regs[DIX.region]['lang'] != 'en':
                # Translate and autoclassification of Events in HIPS
                x = await self.translate_text(val['name'])
            else:
                x = val['name']
            xx = x.replace("'", " ")
            xx = xx.replace(' ', '%')
            DIX.cur.execute(f"""SELECT id FROM groups WHERE cat_id='hips2021' AND name LIKE '%{xx}%' OR name LIKE REPLACE('{label}',' ','') OR description LIKE '%{xx}%' OR
                REPLACE(join_rules,' ','') LIKE REPLACE('{label}',' ','')""")
            row1 = DIX.cur.fetchone()
            if row1:
                print(f"Found.. DI Code:{label} to HIPS:{row1[0]}")
                DIX.cur.execute(f"""UPDATE groups SET join_rules=concat(join_rules, concat('|{DIX.region}=','{label}')) WHERE id='{row1[0]}'""")
                self.commitdb()
            else:
                print(f"NO found {DIX.region}={label}")
        else:
            print(f"Found. DI Code:{label} to HIPS:{row[0]} ({row[1]})")

    def commitdb(self):
        DIX.conn.commit()

    def closedb(self):
        DIX.cur.close()
        DIX.conn.close()

    """ 
    GEOGRAPHY MANAGEMENT SECTION
    """
    ## (step 1b) Get Geography Administrative Unit ID::
    def getGeo(self, code0, code1, code2):
        # Start from the bottom: Level3
        DIX.cur.execute(f"SELECT guuid FROM layer_data WHERE lay_id LIKE '{DIX.region}_lev3%' AND code = '{code2}' order by guuid")
        row = DIX.cur.fetchone()
        if row:
            return row[0]
        else:
            # If not Level2
            DIX.cur.execute(f"SELECT guuid FROM layer_data WHERE lay_id LIKE '{DIX.region}_lev2%' AND code = '{code1}' order by guuid")
            row = DIX.cur.fetchone()
            if row:
                return row[0]
            else:
                # If not Level1
                DIX.cur.execute(f"SELECT guuid FROM layer_data WHERE lay_id LIKE '{DIX.region}_lev1%' AND code = '{code0}' order by guuid")
                row = DIX.cur.fetchone()
                if row:
                    return row[0]
                else:
                    # If not Country
                    DIX.cur.execute(f"SELECT guuid FROM layer_data WHERE lay_id LIKE '{DIX.region}_country%'")
                    row = DIX.cur.fetchone()
                    if row:
                        return row[0]
        print(DIX.cur.query)
        return ""

    # INSERT NATIONAL BOUNDARIES
    def setGeoCountry(self):
        DIX.cur.execute(f"SELECT lay_id FROM layer_data WHERE lay_id='{DIX.region}_country'")
        row = DIX.cur.fetchone()
        if not row and DIX.regs[DIX.region]:
            name = DIX.regs[DIX.region]['name']
            DIX.cur.execute(f"""INSERT INTO layer_data(guuid, lay_id, gid, label, code, name) VALUES (uuid_generate_v4(), 
                '{DIX.region}_country', '{DIX.region}', upper(unaccent('{name}')), '{DIX.region}', '{name}') ON CONFLICT (guuid) DO NOTHING""")
            self.commitdb()
        else:
            print("Region is not available in DIX or already Country Layer exists")

    # INSERT LIST OF GEOGRAPHICAL UNITS FOR LEVELS 1, 2 AND 3 (FROM MAX 3 LEVELS IN DESINVENTAR)
    def setGeography(self, index, val):
        for k, v in val.items():
            if k == "items":
                lv = int(index) + 1
                lev = f"{DIX.region}_lev{lv}"
                DIX.cur.execute(f"SELECT count(1) as total FROM layer_data WHERE lay_id='{lev}'")
                row = DIX.cur.fetchone()
                # Enter only if empty
                if row[0] == 0:
                    for ky, vl in v.items():
                        # Parent selection
                        if len(vl['parent'])== 0:
                            parent = f"(SELECT guuid FROM layer_data WHERE code='{DIX.region}' LIMIT 1)"
                        else:
                            pr_lv = lv - 1
                            pr_lev = f"{DIX.region}_lev{pr_lv}"
                            parent = f"(SELECT guuid FROM layer_data WHERE code='{vl['parent']}' AND lay_id='{pr_lev}' LIMIT 1)"
                        if type(vl['name']) == str:
                            name = vl['name'].replace("'","")
                            DIX.cur.execute(f"""INSERT INTO layer_data(guuid,lay_id,label,code,name,guuid_parent) VALUES (uuid_generate_v4(), 
                                '{lev}',upper(unaccent('{name}')),'{ky}','{name}',{parent}) ON CONFLICT (guuid) DO NOTHING""")
                else:
                    print(f"GEO: for Level {lv}, we found {row[0]} geographic records")
        return False

    # DOWNLOAD DI MAPS AND ASSOCIATE NATIONAL CODES WITH GADM CODE (IMPORT GEOMETRIES)
    # 2025-06-30 mayandar. function used only for first importation.
    def downloadDIMaps(self, shpf):
        import requests
        import zipfile
        import io
        import geopandas as gpd
        from pathlib import Path
        import json
        mypath = f"/tmp/shapefile_temp/{DIX.region}/"
        if shpf:
            myshp = Path(f"{mypath}{shpf[0]['file']}")
            # Shapefile already in folder
            if not myshp.is_file() or DIX.option == "DIonly" or DIX.option == "both":
                # Replace with the URL of your shapefile zip
                shapefile_url = f"http://localhost:8080/maps/{DIX.region}.zip"
                # 1. Download the shapefile zip
                response = requests.get(shapefile_url)
                response.raise_for_status() # Raise an exception for bad status codes
                # 2. Unzip the shapefile
                shapefile_path = []
                with zipfile.ZipFile(io.BytesIO(response.content)) as z:
                    # Find the shapefile (.shp) and related files in the zip
                    for file_info in z.infolist():
                        if file_info.filename.endswith(".shp"):
                            shapefile_path.append(file_info.filename)
                        # Extract all files to a temporary directory
                        z.extractall(mypath)
                # Read and convert Shapefiles to GeoJson
                for shp in shapefile_path:
                    print("Processing: " + shp + "...")
                    # 3. Read the shapefile using geopandas
                    gdf = gpd.read_file(f"{mypath}{shp}")
                    # 4. Export to GeoJSON
                    geojson_data = gdf.to_json()
                    geojson_obj = json.loads(geojson_data)
                    for feature in geojson_obj['features']:
                        properties = feature['properties']
                        geometry = feature['geometry']
                        geometry_json = json.dumps(geometry)
                        for col in shpf:
                            if shp == col['file']:
                                lay_id = f"{DIX.region}_lev{int(col['level'])+1}"
                                cod_value = properties.get(col['colcode'])
                                qry = f"UPDATE layer_data SET geom=ST_SetSRID(ST_GeomFromGeoJSON('{geometry_json}'), 4326) WHERE lay_id='{lay_id}' AND code='{cod_value}'"
                                #print(qry)
                                DIX.cur.execute(qry)
                    DIX.conn.commit()
                    print("Shapefile data successfully inserted")
            else:
                print("Existing DI shapefiles, do nothing")
        else:
            print("No shapefiles")

    # DOWNLOAD MAPS AND ASSOCIATE NATIONAL CODES WITH GID's GADM CODE (IMPORT GEOMETRIES)
    def downloadGADMaps(self):
        import requests
        import zipfile
        import io
        import geopandas as gpd
        from pathlib import Path
        import json
        mypath = "/tmp/shapefile_temp/"
        myshp = Path(f"{mypath}gadm41_{DIX.region}_0.shp")
        if not myshp.is_file() or DIX.option == "DIonly" or DIX.option == "both":
            # Replace with the URL of your shapefile zip
            shapefile_url = f"https://geodata.ucdavis.edu/gadm/gadm4.1/shp/gadm41_{DIX.region}_shp.zip" #f"https://geodata.ucdavis.edu/gadm/gadm4.1/shp/gadm41_{DIX.region}_shp.zip"
            # 1. Download the shapefile zip
            response = requests.get(shapefile_url)
            response.raise_for_status() # Raise an exception for bad status codes
            # 2. Unzip the shapefile
            shapefile_path = []
            with zipfile.ZipFile(io.BytesIO(response.content)) as z:
                # Find the shapefile (.shp) and related files in the zip
                for file_info in z.infolist():
                    if file_info.filename.endswith(".shp"):
                        shapefile_path.append(file_info.filename)
                    # Extract all files to a temporary directory
                    z.extractall(mypath)
            # Read and convert Shapefiles to GeoJson
            for shp in shapefile_path:
                print("Processing: " + shp + "...")
                # 3. Read the shapefile using geopandas
                gdf = gpd.read_file(f"{mypath}{shp}")
                # 4. Export to GeoJSON
                geojson_data = gdf.to_json()
                # Insert GeoJSON data into the table
                geojson_obj = json.loads(geojson_data)
                findgid = False
                for feature in geojson_obj['features']:
                    properties = feature['properties']
                    geometry = feature['geometry']
                    geometry_json = json.dumps(geometry)
                    # Country Level
                    if shp[-5:] == "0.shp":
                        lay_id = DIX.region + "_country"
                        qry = f"UPDATE layer_data SET geom=ST_SetSRID(ST_GeomFromGeoJSON('{geometry_json}'), 4326) WHERE lay_id='{lay_id}' AND geom is null"
                        DIX.cur.execute(qry)
                    # First subnational Level
                    elif shp[-5:] == "1.shp":
                        lay_id = DIX.region + "_lev1"
                        gid_value = properties.get('GID_1')
                        findgid = True
                    # Second subnational level
                    elif shp[-5:] == "2.shp":
                        lay_id = DIX.region + "_lev2"
                        gid_value = properties.get('GID_2')
                        findgid = True
                    # Third subnational level
                    elif shp[-5:] == "3.shp":
                        lay_id = DIX.region + "_lev3"
                        gid_value = properties.get('GID_3')
                        findgid = True
                    # Compare polygons using Hausdorff distance to get the GID
                    if findgid:
                        DIX.cur.execute(f"""SELECT code, ST_HausdorffDistance(geom, ST_SetSRID(ST_GeomFromGeoJSON('{geometry_json}'), 4326)) AS distance 
                            FROM layer_data WHERE ST_Intersects(geom, ST_SetSRID(ST_GeomFromGeoJSON('{geometry_json}'), 4326)) AND lay_id='{lay_id}' ORDER BY distance LIMIT 1""")
                        row = DIX.cur.fetchone()
                        if row:
                            print(f"GEO {lay_id}: found gid {gid_value} for code {row[0]}")
                            qry = f"UPDATE layer_data SET gid='{gid_value}' WHERE lay_id='{lay_id}' AND code='{row[0]}'"
                            DIX.cur.execute(qry)
                            #print(qry)
                    # optional, include GADM geo?
                    else:
                        pass
                DIX.conn.commit()
                print("Shapefile data successfully inserted")
        else:
            print("Existing GADM shapefiles, do nothing")

    # DTS Geography format: Polygon per file in geojson with a list of polygons with parents CSV 
    def exportGeo(self, path):
        DIX.cur.execute(f"""SELECT l.code as id, (select lp.code from layer_data lp where lp.guuid = l.guuid_parent) as parent, 
            concat(replace(l.code,' ',''),'.geojson') as geodata, l.code, l.name FROM layer_data l WHERE l.lay_id LIKE '{DIX.region}_%' 
            AND l.geom is not null ORDER BY lay_id, code""")
        csv = []
        for row in DIX.cur.fetchall():
            csv.append(row)
            geojson_data = self.getGeoJsonFromCode(row[0])
            with open(path + 'geojson/' +  row[2], 'w') as f:
                json.dump(geojson_data, f, indent=2)
        # ey, CSV header file must be "id,parent,geodata,national_id,en"
        df = pd.DataFrame(csv)
        df.to_csv(path + DIX.region + '.csv', index=False, header=["id","parent","geodata","national_id","en"])
    
    # DTS Geography format: conversion in GeoJson format
    def getGeoJsonFromCode(self, code):
        DIX.cur.execute(f"""SELECT jsonb_build_object('type', 'FeatureCollection', 'features', jsonb_agg(feature)) FROM 
        (SELECT jsonb_build_object('type', 'Feature', 'geometry', ST_AsGeoJSON(ST_Transform(geom, 4326))::jsonb, 'properties', 
        jsonb_build_object('name', name)) AS feature FROM (SELECT * from layer_data WHERE lay_id LIKE '{DIX.region}_%' AND code='{code}') inputs) features""")
        return DIX.cur.fetchone()[0]

    # Date validation
    def is_valid_date(self, date_string):
        try:
            datetime.strptime(date_string, "%Y-%m-%d")
            return True
        except ValueError:
            return False

    # DTS Disaster Records Structure
    def getDTSdisasterrecord(self):
        DIX.cur.execute(f"""SELECT rec_uuid, hh.code, serial, year, month, day, duration, sources, g.geogra_id, g.location, hh.level 
            FROM records r, groupsrecord h, groups hh, georecord g, layer_data gg WHERE reg_id='{DIX.region}' and rec_uuid=h.record_id and 
            rec_uuid=g.record_id and h.grp_id=hh.id and g.geogra_id=gg.guuid""")
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["approvalStatus"] = "published"
            # HIPS level
            if row[10] == 1:
                rec["hipTypeId"] = row[1]
            elif row[10] == 2:
                rec["hipClusterId"] = row[1]
            elif row[10] == 3:
                rec["hipHazardId"] = row[1]
            rec["startDate"] = f"{str(row[3]).zfill(4)}-{str(row[4]).zfill(2)}-{str(row[5]).zfill(2)}"
            # Calculate end date using duration
            if row[6] > 0 and self.is_valid_date(rec["startDate"]):
                a = datetime(row[3], row[4], row[5])
                b = a + timedelta(days=row[6])
                rec["endDate"] = f"{str(b.year).zfill(4)}-{str(b.month).zfill(2)}-{str(b.day).zfill(2)}"
            rec["primaryDataSource"] = row[7]
            rec["validatedBy"] = "DIX"
            rec["originatorRecorderInst"] = f"{DIX.region} DesInventar Database"
            DIX.cur.execute(f"""SELECT jsonb_build_object('type', 'FeatureCollection', 'features', jsonb_agg(feature)) 
                FROM (SELECT jsonb_build_object('type', 'Feature', 'geometry', ST_AsGeoJSON(ST_Transform(geom, 4326))::jsonb, 
                'properties', jsonb_build_object('name', name)) AS feature FROM (SELECT * from layer_data WHERE guuid='{row[8]}') inputs) features""")
            geoj = DIX.cur.fetchone()[0]
            rec["spatialFootprint"] = [{"geojson": geoj }]
            rec["locationDesc"] = row[9]
            rec["legacyData"] = {"SERIAL": row[2], "DIID": row[0]}
            #rec["apiImportId"] = row[0]
            data.append(rec)
            results.append(data)
        return results

    # DTS list of Assets for region
    def getDTSassets(self):
        DIX.cur.execute(f"SELECT a.id, a.name, a.sector_id FROM assets a, regeffects e WHERE e.reg_id='{DIX.region}' and e.asset_id=a.id")
        results = []
        for row in DIX.cur.fetchall():
            data = []
            q = dict()
            if row[2] == 'unknown':
                q['sectorIds'] = 9
            else:
                q['sectorIds'] = row[2][3:]
            q['name'] = row[1]
            q['category'] = ''
            q['nationalId'] = row[0]
            q['notes'] = ''
            q['apiImportId'] = row[0]
            data.append(q)
            results.append(data)
        return results

    # DTS ID value to be incorporate the DIX DB making useful
    def syncDTSassets(self, dtsid, diid):
        qry = f"UPDATE regeffects SET dts_assetid='{dtsid}' WHERE asset_id='{diid}' AND reg_id='{DIX.region}'"
        print(qry)
        DIX.cur.execute(qry)
        self.commitdb()

    # DTS Sector Id as part of Damage Record
    def getDTSsectors(self, dtsid, diid):
        qry = f"""select sector, sum(tot), sum(dmg), sum(dst), sum(ecn), sum(disrup) from (
            select a.sector_id as sector, sum(total) as tot, sum(damaged) as dmg, sum(destroyed) as dst, sum(economic) as ecn, null as disrup 
            FROM damages d, assets a WHERE d.record_id='{diid}' and a.id=d.asset_id group by sector UNION 
            select r.sector_id as sector, null as tot, null as dmg, null as dst, null as ecn, sum(disruptnum) as disrup FROM disruptions r  
            WHERE r.record_id='{diid}' group by sector) group by sector"""
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["disasterRecordId"] = dtsid
            if row[0] == 'unknown':
                rec["sectorId"] = "9"
            else:
                rec["sectorId"] = row[0][3:]
            if int(0 if row[1] is None else row[1]) > 0 or int(0 if row[2] is None else row[2]) > 0 or int(0 if row[3] is None else row[3]) > 0:
                rec["withDamage"] = True
            else:
                rec["withDamage"] = False
            rec["damageCost"] = str("0" if row[4] is None else row[4])
            if int(0 if row[5] is None else row[5]) > 0:
                rec["withDisruption"] = True
            else:
                rec["withDisruption"] = False
            #rec["apiImportId"] = row[0] + "|" + dtsid
            data.append(rec)
            results.append(data)
        return results

    # DTS Asset Id and Sector Id as part of Damage Record
    def getDTSdamages(self, dtsid, diid):
        qry = f"""SELECT distinct (e.dts_assetid), a.sector_id, total, destroyed, damaged, economic FROM damages d, regeffects e, assets a 
            WHERE d.record_id='{diid}' and e.asset_id=d.asset_id and dts_assetid is not null and a.id=d.asset_id"""
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["recordId"] = dtsid
            if row[1] == 'unknown':
                rec["sectorId"] = 9
            else:
                rec["sectorId"] = row[1][3:]
            rec["assetId"] = row[0]
            rec["unit"] = "number_count"
            rec["totalDamageAmount"] = int(0 if row[2] is None else row[2])
            if int(0 if row[2] is None else row[2]) > 0:
                rec["totalDamageAmountOverride"] = True
            rec["tdDamageAmount"] = int(0 if row[3] is None else row[3])
            rec["pdDamageAmount"] = int(0 if row[4] is None else row[4])
            data.append(rec)
            results.append(data)
        return results

    # DTS Sector Id as part of Disruption Record
    def getDTSdisruptions(self, dtsid, diid):
        qry = f"""SELECT sector_id, disruptnum FROM disruptions WHERE record_id='{diid}'"""
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["recordId"] = dtsid
            if row[0] == 'unknown':
                rec["sectorId"] = 9
            else:
                rec["sectorId"] = row[0][3:]
            rec["durationDays"] = row[1]
            #rec["apiImportId"] = row[0] + "|" + dtsid
            data.append(rec)
            results.append(data)
        return results

    # DTS HUMAN presence effects 
    """
    def getDTShumaneff(self, diid):
        qry = f"SELECT humaneff_id, value FROM human WHERE record_id='{diid}'"
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            rec = dict()
            if row[1] > 0:
                val = True
            else:
                val = False
            if row[0] == "a2a_tot":
                rec["table"] = "Deaths"
                rec["data"] = {"deaths": val}
            elif row[0] == "b2_tot":
                rec["table"] = "Injured"
                rec["data"] = {"injured": val}
            elif row[0] == "a3a_tot":
                rec["table"] = "Missing"
                rec["data"] = {"missing": val}
            elif row[0] == "victims":
                rec["table"] = "Affected"
                rec["data"] = {"direct": val}
            elif row[0] == "indaffected":
                rec["table"] = "Affected"
                rec["data"] = {"indirect": val}
            results.append(rec)
        return results
    """

    # DTS HUMAN values
    def getDTSHuman(self, diid):
        qry = f"SELECT h.humaneff_id, h.value, f.type from human h, humaneff f WHERE h.record_id='{diid}' and f.id=h.humaneff_id"
        types = {}
        DIX.cur.execute(qry)
        for row in DIX.cur.fetchall():
            if row[1] > 0:
                if row[2] == "directaffected" or row[2] == "indirectaffected":
                    table = "Affected"
                else:
                    table = row[2].capitalize()
                if table not in types:
                    types[table] = []
                    if table == "Affected":
                        types[table].append(["sex", "age", "disability", "globalPovertyLine", "nationalPovertyLine", "direct", "indirect"])
                    else:
                        types[table].append(["sex", "age", "disability", "globalPovertyLine", "nationalPovertyLine", row[2]])
                ids = row[0].split("_")
                if len(ids)==2 and ids[1] == "tot":
                    if row[2] == "directaffected":
                        types[table].append([None, None, None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, None, None, None, None, None, row[1]])
                    else:
                        types[table].append([None, None, None, None, None, row[1]])
                elif len(ids)==2 and ids[1] == "male":
                    if row[2] == "directaffected":
                        types[table].append(["m", None, None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append(["m", None, None, None, None, None, row[1]])
                    else:
                        types[table].append(["m", None, None, None, None, row[1]])
                elif len(ids)==2 and ids[1] == "female":
                    if row[2] == "directaffected":
                        types[table].append(["f", None, None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append(["f", None, None, None, None, None, row[1]])
                    else:
                        types[table].append(["f", None, None, None, None, row[1]])
                elif len(ids)==2 and ids[1] == "adults":
                    if row[2] == "directaffected":
                        types[table].append([None, "15-64", None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, "15-64", None, None, None, None, row[1]])
                    else:
                        types[table].append([None, "15-64", None, None, None, row[1]])
                elif len(ids)==2 and ids[1] == "children":
                    if row[2] == "directaffected":
                        types[table].append([None, "0-14", None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, "0-14", None, None, None, None, row[1]])
                    else:
                        types[table].append([None, "0-14", None, None, None, row[1]])
                elif len(ids)==2 and ids[1] == "elder":
                    if row[2] == "directaffected":
                        types[table].append([None, "65+", None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, "65+", None, None, None, None, row[1]])
                    else:
                        types[table].append([None, "65+", None, None, None, row[1]])
                elif len(ids)==2 and ids[1] == "disabled":
                    if row[2] == "directaffected":
                        types[table].append([None, None, "others", None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, None, "others", None, None, None, row[1]])
                    else:
                        types[table].append([None, None, "others", None, None, row[1]])
                elif len(ids)==2 and ids[1] == "poor":
                    if row[2] == "directaffected":
                        types[table].append([None, None, None, None, "below", row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, None, None, None, "below", None, row[1]])
                    else:
                        types[table].append([None, None, None, None, "below", row[1]])
        return types
