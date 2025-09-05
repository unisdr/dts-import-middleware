from utils.extract import extract_datacards, extract_geo, extract_effects, extract_hazards 
from utils.validation import transform_datacards, transform_geo, transform_eff, transform_hzd
from utils.load import uploadAssets, uploadRecords, exportGeoFiles, testRecords
from utils.DIX import DIX
from datetime import datetime
import logging
import argparse

# Logger initialization
logging.basicConfig(format='[%(levelname)s]: %(message)s', level=logging.INFO)

if __name__ == '__main__':
    # Initialize parser
    parser = argparse.ArgumentParser(description='DIX: An ETL tool to Disasters LDD data')
    # Adding optional argument
    parser.add_argument("-c", "--Country", help = "Set a country, ISO3code in capital letters")
    parser.add_argument("-m", "--Mode", help = "Mode: setgeography, sethazards, seteffects, datacards")
    parser.add_argument("-g", "--retrygeo", help = "DIonly or GADMonly or both")
    parser.add_argument("-u", "--Upload", help = "assets, disrecords, geofiles, testrec")
    # Read arguments from command line
    args = parser.parse_args()
    if args.Country:
        """
        COL_bog, COL_ant, COL_cal
        IND_033, IND_005, IND_019
        PAC_asm, PAC_cok, PAC_etm, PAC_fsm, PAC_fji, PAC_pyf, PAC_gum, PAC_kir, PAC_mhl, PAC_nru, PAC_ncl, 
        PAC_niu, PAC_mnp, PAC_pwl, PAC_png, PAC_wsm, PAC_slb, PAC_tkl, PAC_ton, PAC_tuv, PAC_vut, PAC_wlf
        """
        cty = args.Country
        dix = DIX(cty, False)
        myurl =  "https://desinventar-api.undrr.org/api/" #"http://localhost:8081/" #
        head = {'Content-Type':'application/json', 'Authorization': 'Bearer {}'.format("cj7pmujA1Zu99H1ZBhsr")} #{'Content-Type':'application/json'} #
        logging.info(f'[{cty}]: Starting ETL process {datetime.now()}')
        for reg in dix.getRegion():
            if reg:
                if args.Mode == "datacards":
                    # Extract process from DIS (Disaster Information System)
                    nextpage = 0 # First page = 0
                    logging.info(f'[{cty}]: Starting datacards transformation process...')
                    while True:
                        cards_df = extract_datacards(myurl, head, reg, nextpage)
                        # Validation of datacards process
                        if not cards_df.empty:
                            nextpage = cards_df.iloc[0]['nextPage']
                            logging.info(f"[{cty}]: Next page {nextpage}")
                            transform_datacards(dix, cards_df['datacards'])
                            if nextpage == "nonext":
                                logging.info(f"[{cty}]: Total datacards: {cards_df.iloc[0]['records']}")
                                break
                        else:
                            break
                if args.Mode == "setgeography":
                    # Extract and Transform
                    logging.info(f'[{cty}]: Starting DBSetup Extract & transform to GEO')
                    geo_df = extract_geo(dix, myurl, head, reg)
                    transform_geo(dix, geo_df)
                elif args.Mode == "seteffects":
                    # Extract and Transform
                    logging.info(f'[{cty}]: Starting DBSetup Extract & transform to EFFECTS')
                    eff_df = extract_effects(dix, myurl, head, reg)
                    transform_eff(dix, eff_df)
                elif args.Mode == "sethazards":
                    # Extract and Transform
                    logging.info(f'[{cty}]: Starting DBSetup Extract & transform to HAZARDS')
                    hzd_df = extract_hazards(dix, myurl, head, reg)
                    transform_hzd(dix, hzd_df)
                if args.Upload == "assets":
                    # Loading data process
                    logging.info(f'[{cty}]: Starting loading process to upload Assets of the Region')
                    uploadAssets(dix)
                elif args.Upload == "disrecords":
                    # Loading data process
                    logging.info(f'[{cty}]: Starting loading process to upload Disasters Records')
                    uploadRecords(dix)
                elif args.Upload == "testrec":
                    # Loading data process
                    logging.info(f'[{cty}]: Starting loading process to test records')
                    testRecords(dix)
                elif args.Upload == "geofiles":
                    # Generate CSV and GeoJSON files in DTS format
                    logging.info(f'[{cty}]: Starting generation of generate DTS geofiles')
                    exportGeoFiles(dix)
            else:
                logging.info(f'[{reg}]: Error. Invalid Region. Exiting..')
        logging.info(f'[{cty}]: Finishing ETL process {datetime.now()}')
        dix.closedb()
