import requests

#action = "hips/type/list?page="
#action = "hips/cluster/list?page="
#action = "hips/hazard/list?page="
#action = "division/list?page="
#action = "division/delete_all"
action = "asset/list?page="
#action = "sector/list"
#action = "disaster-record/list?page="
#action = "disaster-record/delete/:id"
from datetime import datetime
### SEYCHELLES
headers = {"X-Auth": "5cc7c1eab7220f0bb9e855190c5f1f9b916e6073261ebfa81470dca6e1b06fd9"}
try:
    page = 1
    while True:
        url = "https://dts-training.undrr.org/en/api/" + action + str(page)
        response = requests.get(url, headers=headers)
        data = response.json()['data']
        pags = data['pagination']
        total = pags['totalItems']
        onpage = pags['pageSize']
        for items in data['items']:
            print(items)
            #url2 = "https://dts-training.undrr.org/en/api/disaster-record/delete/" + items['id']
            #print(url2)
            #response = requests.delete(url2, headers=headers)
            #print(response.json())
        if (page * onpage < total ):
            page += 1
        else:
            break
except requests.exceptions.HTTPError as e:
    print(f"HTTP Error: {e}")
except requests.exceptions.RequestException as e:
    print(f"Request Error: {e}")
except requests.exceptions.JSONDecodeError:
    print("Error: Could not decode JSON from the response.")
