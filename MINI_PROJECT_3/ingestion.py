import paho.mqtt.client as mqtt
import json
import ssl
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
from config import *

# --- Setup InfluxDB client ---

influx_client = InfluxDBClient(
    url=INFLUX_URL,
    token=INFLUX_TOKEN,
    org=INFLUX_ORG
)
write_api = influx_client.write_api(write_options=SYNCHRONOUS)

print("✅ Connected to InfluxDB")

# --- Function to save data to InfluxDB ---

def save_to_influxdb(data):
    """
    Write one telemetry reading to InfluxDB.
    'Point' is how InfluxDB structures data — measurement + tags + fields.
    """
    point = (
        Point("energy_telemetry")           
        .tag("device_id", data["device_id"])
        .field("voltage", data["voltage"])   
        .field("current", data["current"])
        .field("power", data["power"])
        .field("energy", data["energy"])
        .field("power_factor", data["power_factor"])
        .field("frequency", data["frequency"])
    )

    write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=point)
    print(f"   💾 Saved to InfluxDB: [{data['device_id']}] power={data['power']}W")

# --- MQTT Callbacks ---

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Connected to HiveMQ broker!")
        # Subscribe to ALL meter topics using wildcard #
        client.subscribe(f"{MQTT_TOPIC}/#", qos=1)
        print(f"📡 Subscribed to topic: {MQTT_TOPIC}/#\n")
    else:
        print(f"❌ Connection failed with code {rc}")

def on_message(client, userdata, msg):
    """Called every time a message arrives"""
    try:
        # Decode the JSON message
        payload = json.loads(msg.payload.decode("utf-8"))
        print(f"📥 Received from [{msg.topic}]: {payload['device_id']} | "
              f"power={payload['power']}W")

        # Save it to InfluxDB
        save_to_influxdb(payload)

    except Exception as e:
        print(f"❌ Error processing message: {e}")

# --- Setup MQTT client ---

client = mqtt.Client(client_id="energy-ingestion", protocol=mqtt.MQTTv311)
client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
client.tls_set(tls_version=ssl.PROTOCOL_TLS)
client.on_connect = on_connect
client.on_message = on_message

print(f"🔌 Connecting to {MQTT_BROKER}:{MQTT_PORT}...")
client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)

# loop_forever() blocks and keeps listening indefinitely
print("👂 Listening for messages... Press Ctrl+C to stop.\n")
client.loop_forever()
