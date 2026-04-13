import psycopg2
import hashlib
import json
from datetime import datetime, timedelta
from googletrans import Translator
import pandas as pd
from psycopg2 import errors
import uuid
import unicodedata
import re

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

    def __init__(self, region):
        """Initializes a Region Object."""
        DIX.region = region
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

    def setRegionURLKEY(self, server, key):
        print(DIX.region)
        upd = f"""UPDATE region SET export_url='{server}', export_apikey='{key}' WHERE region_id='{DIX.region}'"""
        DIX.cur.execute(upd)
        self.commitdb()


    def getRegion(self):
        return DIX.regs

    ## (step 1) Process for table RECORDS::
    ## rec_uuid, reg_id, hzd_id, serial, year, month, day, sources,comments, card_usereff, status, created, updated, card_causevent, 
    ## eff_econusd, eff_econlcu, card_other, card_withothersector, card_geolocation, card_version
    def insertDIXRecord(self, index, val):
        DIX.jso = json.dumps(val)
        # Generate Record data version
        ver = hashlib.md5(DIX.jso.encode()).hexdigest()
        now = datetime.now()
        try:
            # Get the HIP Id based on Event-Cause
            hzd = self.getHips(val['hzd_label'], val['hzd_event'], val['hzd_cause'])
            if hzd == "OTHER":
                status = "draft"
            else:
                status = "published"
            # CREATE or UPDATE only changed RECORDS based on MD5 card_version field ;)
            sqlrec = f"""INSERT INTO records as r (rec_uuid,reg_id,serial,year,month,day,duration,sources,eff_econusd,eff_econlcu,eff_other,
                eff_withother,card_version,status,created,card_userdate) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) ON CONFLICT (rec_uuid) DO 
                UPDATE SET serial=EXCLUDED.serial, year=EXCLUDED.year, month=EXCLUDED.month, day=EXCLUDED.day, duration=EXCLUDED.duration, 
                card_version=EXCLUDED.card_version, updated='{now}' WHERE r.card_version<>'{ver}' and r.rec_uuid='{index}';"""
            rec = (index, DIX.region, val["rec_serial"], val["eff_year"], val["eff_month"], val["eff_day"], val["hzd_eventduration"], val["rec_sources"],
                val["eff_lossesusd"], val["eff_losseslcu"], val["eff_others"], val["eff_withothers"], ver, status, now, f"""{val["rec_user"]}|{val["rec_date"]}""" )
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
                    if 'tot' in v.keys() and v['tot'] in val.keys() and isinstance(val[v['tot']], (int,float)) and val[v['tot']] > 0:
                        tot = val[v['tot']]
                        flg = True
                    if 'dmg' in v.keys() and v['dmg'] in val.keys() and isinstance(val[v['dmg']], (int,float)) and val[v['dmg']] > 0:
                        dmg = val[v['dmg']]
                        flg = True
                    if 'dst' in v.keys() and v['dst'] in val.keys() and isinstance(val[v['dst']], (int,float)) and val[v['dst']] > 0:
                        dst = val[v['dst']]
                        flg = True
                    if 'eco' in v.keys() and v['eco'] in val.keys() and isinstance(val[v['eco']], (int,float)) and val[v['eco']] > 0:
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

    ## (step 1a) Get HIPs ID using Region, Event and Cause:: HIPS 2025 version used.
    def getHips(self, label, event, cause):
        eve = event.replace("'", "")
        cau = "" if cause is None else cause.replace("'", "")
        DIX.cur.execute(f"""SELECT id FROM groups WHERE cat_id='hips2025' AND (join_rules LIKE '%={label.strip()}%' OR join_rules LIKE '%{DIX.region}={label.strip()}%'
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
        ## ASSETS
        query = f"""SELECT id, codeqt_tot, codeqt_dst, codeqt_dmg, codeqt_eco, a.extid FROM assets a, regeffects re WHERE 
            (codeqt_tot like '%{index}%' OR codeqt_dst like '%{index}%' OR codeqt_dmg like '%{index}%' OR codeqt_eco like '%{index}%') AND
            a.id=re.asset_id and reg_id='{DIX.region}'"""
        DIX.cur.execute(query)
        row = DIX.cur.fetchone()
        # New relation Region - Effect-ASSET
        if row:
            if isinstance(row[1], str) or isinstance(row[2], str) or isinstance(row[3], str) or isinstance(row[4], str):
                ## EXTID is null when basic effects is setted
                qry_a = f"""INSERT INTO regeffects(reg_id, asset_id, extid) SELECT '{DIX.region}', '{row[0]}', '{str("" if row[5] is None else row[5])}'
                WHERE NOT EXISTS (select * from regeffects where reg_id='{DIX.region}' and asset_id='{row[0]}')"""
#                print(query)
                DIX.cur.execute(qry_a)
                print(f">> Setting a new Effect to ASSET: {row[0]}")
                #print(qry_a)
        else:
            ## HUMAN EFFECTS
            DIX.cur.execute(f"SELECT id, codeqt, codeql FROM humaneff WHERE codeqt like '%{index}%' OR codeql like '%{index}%';")
            row = DIX.cur.fetchone()
            # New relation Region - Effect
            if row:
                if isinstance(row[1], str) or isinstance(row[2], str):
                    qry_h = f"""INSERT INTO regeffects(reg_id, humaneff_id) SELECT '{DIX.region}', '{row[0]}'
                    WHERE NOT EXISTS (select * from regeffects where reg_id='{DIX.region}' and humaneff_id='{row[0]}')"""
                    DIX.cur.execute(qry_h)
                    print(f">> Setting a new Effect to HUMAN: {row[0]}")
                    #print(qry_h)
            else:
                # SECTORS
                DIX.cur.execute(f"SELECT id, codeql FROM sectors WHERE codeql like '%{index}%';")
                row = DIX.cur.fetchone()
                # New relation Region - Effect
                if row:
                    if isinstance(row[1], str):
                        qry_s = f"""INSERT INTO regeffects(reg_id, sector_id) SELECT '{DIX.region}', '{row[0]}'
                        WHERE NOT EXISTS (select * from regeffects where reg_id='{DIX.region}' and humaneff_id='{row[0]}')"""
                        DIX.cur.execute(qry_s)
                        print(f">> Setting a new Effect to SECTOR: {row[0]}")
                        #print(qry_s)
                else:
                    ## NEW Effects classification
                    if not index in excl:
                        description = "" if val['name'] is None else val['name'].replace("'", "") + ": " + "" if val['description'] is None else val['description'].replace("'","")
                        if DIX.regs[DIX.region]['lang'] != 'en':
                            # Translate and autoclassification of country-defined Effects names
                            x = await self.translate_text(description.lower())
                        else:
                            x = description.lower()
                        # DIX try to catch new effect type human using keywords
                        if x.find('famil') != -1 or x.find('child') != -1 or x.find('person') != -1 or x.find('people') != -1:
                            qry_h = f"""INSERT INTO humaneff(id, description, type, codeqt) VALUES ('{DIX.region}={index}', '{description}', 
                                'otherhuman', '={index}') ON CONFLICT (id) DO NOTHING"""
                            DIX.cur.execute(qry_h)
                            #print(qry_h)
                            qry2_h = f"""INSERT INTO regeffects(reg_id, humaneff_id) SELECT '{DIX.region}', '{DIX.region}={index}'
                            WHERE NOT EXISTS (select * from regeffects where reg_id='{DIX.region}' and humaneff_id='{DIX.region}={index}')"""
                            DIX.cur.execute(qry2_h)
                            print(f">>>> Setting a new Effect(translated) to HUMAN: {DIX.region}={index}")
                            #print(qry2_h)
                        else:
                            if description == "":
                                description = DIX.region + ": " + index
                            name = description
                            measure = "units" if val['fieldtype'] is None else val['fieldtype'].replace("'", "")
                            code = 'codeqt_tot'
                            ## ID04: Sector Cross-cutting
                            qry_a = f"""INSERT INTO assets(id, {code}, measure, name, description, sector_id) VALUES ('{DIX.region}={index}', '={index}', '{measure}', 
                                '{name}', '{description}', '04') ON CONFLICT (id) DO NOTHING"""
                            DIX.cur.execute(qry_a)
                            qry2_a = f"""INSERT INTO regeffects(reg_id, asset_id) SELECT '{DIX.region}', '{DIX.region}={index}'
                            WHERE NOT EXISTS (select * from regeffects where reg_id='{DIX.region}' and asset_id='{DIX.region}={index}')"""
                            DIX.cur.execute(qry2_a)
                            print(f">>>> Setting a new Effect(translated) to ASSET: {DIX.region}={index}")
                            #print(qry2_a)

    async def translate_text(self, text, dest_language='en', src_language='auto'):
        async with Translator() as translator:
            result = await translator.translate(text, dest=dest_language, src=src_language)
            return result.text

    async def setHIPsRules(self, index, val):
        #print(index, val)
        label = index.replace("'", " ")
        label = label.upper()
        q1 = f"SELECT id,fullname FROM groups WHERE cat_id='hips2025' AND (join_rules LIKE '%={label}%' OR join_rules LIKE '%?{label}>%' OR join_rules LIKE '%{DIX.region}={index}%')"
        DIX.cur.execute(q1)
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
            q2 = f"""SELECT id FROM groups WHERE cat_id='hips2025' AND (upper(name) LIKE '%{xx.upper()}%' OR upper(name) LIKE REPLACE('{label}',' ','') OR 
                upper(keywords) LIKE '%{xx.upper()}%' OR REPLACE(join_rules,' ','') LIKE REPLACE('{label}',' ',''))"""
            DIX.cur.execute(q2)
            row1 = DIX.cur.fetchone()
            if row1:
                print(f"Found (2pass) DI Code:{label} to HIPS:{row1[0]}")
                q3 = f"""UPDATE groups SET join_rules=concat(join_rules, concat('|{DIX.region}=','{label}')) WHERE id='{row1[0]}'"""
                DIX.cur.execute(q3)
                self.commitdb()
            else:
                q4 = f"""SELECT id FROM groups WHERE cat_id='hips2025' AND (upper(description) LIKE '%{label}%' OR upper(description) LIKE '%{xx.upper()}%')"""
                DIX.cur.execute(q4)
                row2 = DIX.cur.fetchone()
                if row2:
                    print(f"Found (3pass) DI Code:{label} to HIPS:{row2[0]}")
                    q5 = f"""UPDATE groups SET join_rules=concat(join_rules, concat('|{DIX.region}=','{label}')) WHERE id='{row2[0]}'"""
                    DIX.cur.execute(q5)
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

    def strip_accents(self, text):
        try:
            text = str(text)
        except NameError:
            pass
        normalized_text = unicodedata.normalize('NFD', text)
        unaccented_text = re.sub(r'[\u0300-\u036f]', '', normalized_text)
        return unaccented_text

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
            myuuid = str(uuid.uuid4())
            DIX.cur.execute(f"""INSERT INTO layer_data(guuid, lay_id, gid, label, code, name) VALUES ('{myuuid}', 
                '{DIX.region}_country', '{DIX.region}', upper('{self.strip_accents(name)}'), '{DIX.region}', '{name}') ON CONFLICT (guuid) DO NOTHING""")
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
                            myuuid = str(uuid.uuid4())
                            name = vl['name'].replace("'","")
                            DIX.cur.execute(f"""INSERT INTO layer_data(guuid,lay_id,label,code,name,guuid_parent) VALUES ('{myuuid}', 
                                '{lev}',upper('{self.strip_accents(name)}'),'{ky}','{name}',{parent}) ON CONFLICT (guuid) DO NOTHING""")
                else:
                    print(f"GEO: for Level {lv}, DIX found {row[0]} geographic records")
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
            # Not Shapefile found in folder, download
            shapefile_path = []
            if not myshp.is_file():
                # Replace with the URL of your shapefile zip
                ###shapefile_url = f"http://192.168.0.22:8080/maps/{DIX.region}.zip"
                # 1. Download the shapefile zip
                ###response = requests.get(shapefile_url)
                ###response.raise_for_status() # Raise an exception for bad status codes
                # 2. Unzip the shapefile
                ###with zipfile.ZipFile(io.BytesIO(response.content)) as z:
                with zipfile.ZipFile(f"/tmp/DIX/maps/{DIX.region}.zip", 'r') as z:
                    # Find the shapefile (.shp) and related files in the zip
                    for file_info in z.infolist():
                        if file_info.filename.endswith(".shp"):
                            shapefile_path.append(file_info.filename)
                        # Extract all files to a temporary directory
                        z.extractall(mypath)
                print("New shapefiles found in DI")
            # Use existing Shapefiles
            else:
                path = Path(mypath)
                files_only = [p.name for p in path.iterdir() if p.is_file()]
                for file_info in files_only:
                    finfo = str(file_info)
                    if finfo[-3:] == "shp":
                        shapefile_path.append(finfo)
            # Read and convert Shapefiles to GeoJson
            for shp in shapefile_path:
                print("Processing DI: " + shp + "...")
                # 3. Read the shapefile using geopandas
                gdf = gpd.read_file(f"{mypath}{shp}")
                # 4. Export to GeoJSON
                ## Identify Date time columns to be dropped
                date_columns = gdf.select_dtypes(include=['datetime64[ns]']).columns
                gdf.drop(columns=date_columns, inplace=True)
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
            print("No shapefiles found")

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
        if not myshp.is_file():
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
                print("Processing GADM: " + shp + "...")
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

    # Set External Geography Id from DTS
    def setDTSgeography(self, dtsgeoid, nationalid):
        upd = f"""UPDATE layer_data SET extid='{dtsgeoid}' WHERE code='{nationalid}' AND lay_id like '{DIX.region}_%' and extid is null"""
        DIX.cur.execute(upd)
        self.commitdb()

    ##############################
    ### ***** DTS FUNCTIONS ******
    # DTS Geography format: Polygon per file in geojson with a list of polygons with parents CSV 
    def exportGeo(self, path):
        # ey, CSV header file must be "id,parent,geodata,national_id,en"
        if DIX.regs[DIX.region]['lang'] == "en":
            DIX.cur.execute(f"""SELECT regexp_replace(l.code, '[^\\w]+','') as id, (select lp.code from layer_data lp where lp.guuid = l.guuid_parent) as parent, 
                concat(regexp_replace(l.code, '[^\\w]+',''),'.geojson') as geodata, l.code, l.name FROM layer_data l WHERE l.lay_id LIKE '{DIX.region}_%' 
                AND l.geom is not null ORDER BY lay_id, code""")
            hdr=["id","parent","geodata","national_id",DIX.regs[DIX.region]['lang']]
        else:
            DIX.cur.execute(f"""SELECT regexp_replace(l.code, '[^\\w]+','') as id, (select lp.code from layer_data lp where lp.guuid = l.guuid_parent) as parent, 
                concat(regexp_replace(l.code, '[^\\w]+',''),'.geojson') as geodata, l.code, l.label, l.name FROM layer_data l WHERE l.lay_id LIKE '{DIX.region}_%' 
                AND l.geom is not null ORDER BY lay_id, code""")
            hdr=["id","parent","geodata","national_id","en",DIX.regs[DIX.region]['lang']]
        csv = []
        for row in DIX.cur.fetchall():
            csv.append(row)
            geojson_data = self.getGeoJsonFromCode(row[0])
            with open(path + 'geojson/' +  row[2], 'w', encoding='utf-8') as f:
                json.dump(geojson_data, f, indent=2)
            df = pd.DataFrame(csv)
            df.to_csv(path + DIX.region + '.csv', index=False, header=hdr)
    
    # DTS Geography format: conversion in GeoJson format
    def getGeoJsonFromCode(self, code):
        DIX.cur.execute(f"""SELECT jsonb_build_object('type', 'FeatureCollection', 'features', jsonb_agg(feature)) FROM 
        (SELECT jsonb_build_object('type', 'Feature', 'geometry', ST_AsGeoJSON(ST_Transform(geom, 4326))::jsonb, 'properties', 
        jsonb_build_object('name', name)) AS feature FROM (SELECT * from layer_data WHERE lay_id LIKE '{DIX.region}_%' AND code='{code}' AND geom is not null) inputs) features""")
        return DIX.cur.fetchone()[0]

    # Date validation ** Not used
    def is_valid_date(self, date_string):
        try:
            datetime.strptime(date_string, "%Y-%m-%d")
            return True
        except ValueError:
            return False

    # DTS Disaster Records SENT
    def getDTSdisasterrecord_sent(self):
        DIX.cur.execute(f"""SELECT rec_uuid, extid FROM records WHERE reg_id='{DIX.region}' and status='published' and r.extid is not null""")
        results = []
        for row in DIX.cur.fetchall():
            results['ID'] = row[0]
            results['EXT'] = row[1]
        return results

    # DTS Disaster Records ADD Extid
    def setDTSdisasterrecord(self, diid, dtsid):
        upd = f"""UPDATE records SET extid='{dtsid}' WHERE rec_uuid='{diid}'"""
        DIX.cur.execute(upd)
        self.commitdb()
    
    # DTS Disaster Records Delete Extid
    def deleteRecords(self, extid):
        upd = f"""UPDATE records SET extid=null WHERE extid='{extid}'"""
        DIX.cur.execute(upd)
        self.commitdb()

    # DTS Disaster Records Structure - No send DRecords
    def getDTSdisasterrecord(self):
        DIX.cur.execute(f"""SELECT rec_uuid, hh.id as hips, serial, year, month, day, duration, sources, g.geogra_id, g.location, hh.level, r.extid, r.card_userdate, 
            gg.label, gg.extid FROM records r, groupsrecord h, groups hh, georecord g, layer_data gg WHERE reg_id='{DIX.region}' and rec_uuid=h.record_id and 
            rec_uuid=g.record_id and h.grp_id=hh.id and hh.cat_id='hips2025' and g.geogra_id=gg.guuid and r.status='published' and r.extid is null ORDER BY year, month, day""")
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["approvalStatus"] = "published"
            # HIPS levels 1,2,3
            q1 = f"""WITH RECURSIVE group_ancestors AS (
                SELECT extid, id, parent_id, fullname, level FROM groups WHERE id='{row[1]}' and cat_id='hips2025' UNION ALL
                SELECT g.extid, g.id, g.parent_id, g.fullname, g.level FROM groups g JOIN group_ancestors ga ON g.id=ga.parent_id
            ) SELECT extid, level FROM group_ancestors"""
            DIX.cur.execute(q1)
            rec["hipTypeId"] = None
            rec["hipClusterId"] = None
            rec["hipHazardId"] = None
            for hips in DIX.cur.fetchall():
                if hips[1] == 3:
                    rec["hipHazardId"] = hips[0]
                elif hips[1] == 2:
                    rec["hipClusterId"] = hips[0]
                elif hips[1] == 1:
                    rec["hipTypeId"] = hips[0]
            # Dates Start - End
            if (row[4]==0 or row[4] is None) or (row[5]==0 or row[5] is None):
                #startdate = datetime.strptime(f"{str(row[3]).zfill(4)}", "%Y")
                rec["startDate"] = f"{str(row[3]).zfill(4)}"
            elif (row[5]==0 or row[5] is None):
                #startdate = datetime.strptime(f"{str(row[3]).zfill(4)}-{str(row[4]).zfill(2)}", "%Y-%m")
                rec["startDate"] = f"{str(row[3]).zfill(4)}-{str(row[4]).zfill(2)}"
            else:
                #startdate = datetime.strptime(f"{str(row[3]).zfill(4)}-{str(row[4]).zfill(2)}-{str(row[5]).zfill(2)}", "%Y-%m-%d")
                rec["startDate"] = f"{str(row[3]).zfill(4)}-{str(row[4]).zfill(2)}-{str(row[5]).zfill(2)}"
            rec["endDate"] = None
            """
            if row[6] > 0 and self.is_valid_date(rec["startDate"]):
                startdate = datetime.now()
                b = startdate + timedelta(days=row[6])
                rec["endDate"] = f"{str(b.year).zfill(4)}-{str(b.month).zfill(2)}-{str(b.day).zfill(2)}"
            """
            rec["primaryDataSource"] = row[7]
            rec["validatedBy"] = row[12]
            rec["originatorRecorderInst"] = f"{DIX.region} DesInventar Database"
            if row[14] is not None:
                rec["spatialFootprint"] = [{"id":"", "title": row[13], "division_id": row[14], "map_option": "Geographic level"}]
            """
            else:
                # Checking no empty geography geom?
                if row[15] is None:
                    geoj = {}
                else:
                    DIX.cur.execute(f"SELECT jsonb_build_object('type', 'FeatureCollection', 'features', jsonb_agg(feature))  
                        FROM (SELECT jsonb_build_object('type', 'Feature', 'geometry', ST_AsGeoJSON(ST_Transform(geom, 4326))::jsonb, 
                        'properties', jsonb_build_object('description', name)) AS feature FROM (SELECT * from layer_data WHERE guuid='{row[8]}') inputs) features")
                    geoj = DIX.cur.fetchone()[0]
                rec["spatialFootprint"] = [{"id":"null", "title": row[13], "geojson": geoj, "map_option": "Map Coordinates"}]
            """
            rec["locationDesc"] = row[9]
            rec["legacyData"] = {"SERIAL": row[2], "DIID": row[0]}
            #if row[11] is None:
            #    rec["apiImportId"] = "null"
            #else:
            rec["apiImportId"] = row[0]
            data.append(rec)
            results.append(data)
        return results

    # DTS list of New Assets per region
    def getDTSnewassets(self):
        DIX.cur.execute(f"""SELECT a.id, a.name, a.sector_id, s.extid FROM assets a, sectors s, regeffects e 
        WHERE e.reg_id='{DIX.region}' and e.asset_id=a.id and a.sector_id=s.id and a.extid is null""")
        results = []
        for row in DIX.cur.fetchall():
            data = []
            q = dict()
            # use external ID used in DTS/DELTA
            q['sectorIds'] = row[3]
            q['name'] = row[1]
            q['category'] = ''
            q['nationalId'] = row[0]
            q['notes'] = ''
            q['apiImportId'] = row[0]
            data.append(q)
            results.append(data)
        return results

    # DTS ID value to be incorporate the DIX DB making useful
    def setDTSassets(self, dtsid, diid):
        qry = f"UPDATE regeffects SET extid='{dtsid}' WHERE reg_id='{DIX.region}' and asset_id='{diid}'"
        DIX.cur.execute(qry)
        self.commitdb()

    # DTS Sector Id as part of Damage Record
    def getDTSsectors(self, dtsid, diid):
        qry = f"""SELECT sector, sum(tot), sum(dmg), sum(dst), sum(ecn), sum(disrup) from (
            select s.extid as sector, sum(total) as tot, sum(damaged) as dmg, sum(destroyed) as dst, sum(economic) as ecn, null as disrup 
            FROM damages d, assets a, sectors s WHERE d.record_id='{diid}' and a.id=d.asset_id and a.sector_id=s.id group by sector UNION 
            select s.extid as sector, null as tot, null as dmg, null as dst, null as ecn, sum(disruptnum) as disrup FROM disruptions r, sectors s  
            WHERE r.record_id='{diid}' and r.sector_id=s.id group by sector) group by sector;"""
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["disasterRecordId"] = dtsid
            # use DTS ID (extid)
            rec["sectorId"] = row[0]
            if int(0 if row[1] is None else row[1]) > 0 or int(0 if row[2] is None else row[2]) > 0 or int(0 if row[3] is None else row[3]) > 0:
                rec["withDamage"] = True
            else:
                rec["withDamage"] = False
            if int(0 if row[5] is None else row[5]) > 0:
                rec["withDisruption"] = True
            else:
                rec["withDisruption"] = False
            """
            rec["damageCost"] = str("0" if row[4] is None else row[4])
            rec["damageRecoveryCostCurrency"] = 'MZN'
            rec["damageRecoveryCost"] = '0'
            rec["withLosses"] = True
            rec["lossesCost"] = "100.01"
            rec["lossesCostCurrency"] = "example string"
            """
            #rec["apiImportId"] = row[0] + "|" + dtsid
            data.append(rec)
            results.append(data)
        return results

    # DTS Asset Id and Sector Id as part of Damage Record
    def getDTSdamages(self, dtsid, diid):
        qry = f"""SELECT distinct (e.extid), s.extid, total, destroyed, damaged, economic FROM damages d, regeffects e, assets a, sectors s 
            WHERE d.record_id='{diid}' and e.asset_id=d.asset_id and e.extid is not null and a.id=d.asset_id and a.sector_id=s.id"""
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["recordId"] = dtsid
            # use DTS ID (extid) for sector
            rec["sectorId"] = row[1]
            # use DTS ID (extid) for asset
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
        qry = f"""SELECT s.extid, disruptnum FROM disruptions r, sectors s WHERE record_id='{diid}' and r.sector_id=s.id"""
        DIX.cur.execute(qry)
        results = []
        for row in DIX.cur.fetchall():
            data = []
            rec = dict()
            rec["recordId"] = dtsid
            # use DTS ID (extid) for sector
            rec["sectorId"] = row[0]
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
        qry = f"SELECT h.humaneff_id, h.value, f.type from human h, humaneff f WHERE h.record_id='{diid}' and f.id=h.humaneff_id and h.value>0"
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
                    elif table == "Displace":
                        types[table].append(["sex", "age", "disability", "globalPovertyLine", "nationalPovertyLine", "assisted", "timing", "duration", "asOf", "displaced"])
                    else:
                        types[table].append(["sex", "age", "disability", "globalPovertyLine", "nationalPovertyLine", row[2]])
                ids = row[0].split("_")
                if len(ids)==2 and ids[1] == "tot":
                    if row[2] == "directaffected":
                        types[table].append([None, None, None, None, None, row[1], None])
                    elif row[2] == "indirectaffected":
                        types[table].append([None, None, None, None, None, None, row[1]])
                    elif row[2] == "displace":
                        types[table].append([None, None, None, None, None, None, None, None, None, row[1]])
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

    def insertLog(self, recid, log):
        query = f"""INSERT INTO transfer_log (reg_id, recordid, lastupdate, log) VALUES ('{DIX.region}', '{recid}', NOW(), '{log.replace("'", "")}');"""
        DIX.cur.execute(query)
        self.commitdb()
