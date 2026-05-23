# MiniProjectCloudEngineer4

## MINI PROJECT 3 HOW TO

1. Create account on `hivemq.com`, create a cluster, set a username & password, note the url, and access token.
2. Create account on `influxdata.com`, create an organization (note it), create a buckets, set up the username & password, note the url & access token.
3. Set up python environment using `venv`. Then activate it.
4. Install python lib: `paho-mqtt` & `influxdb-client`.
5. Create a `config.py` for env vars. Include all credential & url here.
6. Create the `simulator.py` script. This script pretends to be multiple electricity meters.
7. Create the ingestion service `ingestion.py`. This script listens for messages and saves them to influxdb.
8. Open terminal1 and `source venv/bin/activate`. Then run `python ingestion.py`.
9. Open terminal1 and `source venv/bin/activate`. Then run `python simulator.py`.
10. Let them running.
11. Go to `grafana.com`. Create an account. Go to `connections` >  `data sources` > `add new data source` > `influxdb` > add influxdb url, flux language, Influxdb cloud serverless. Complete the database settings like organization and access token.
12. `save & test` > `datasource is working. 3 buckets found`.
13. Create a `new dashboard` > `add panel` > `add the query` > `refresh`. it will show the visualization.
14. See the captured visualization.
 
