import paho.mqtt.client as mqtt
import json
import time
import random
import ssl
from config import *


def on_connect(client, userdata, flags, rc):
    """Called when successfully connected to the broker"""
    if rc == 0:
        print("✅ Connected to HiveMQ broker!")
    else:
        print(f"❌ Connection failed with code {rc}")

def on_publish(client, userdata, mid):
    """Called when a message is successfully published"""
    print(f"   📤 Message published (id={mid})")


client = mqtt.Client(client_id="energy-simulator", protocol=mqtt.MQTTv311)
client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)

# Enable TLS/SSL (required by HiveMQ Cloud)
client.tls_set(tls_version=ssl.PROTOCOL_TLS)

# Attach callbacks
client.on_connect = on_connect
client.on_publish = on_publish

# Connect to broker
print(f"🔌 Connecting to {MQTT_BROKER}:{MQTT_PORT}...")
client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
client.loop_start()  # runs the network loop in background thread

time.sleep(2)  # wait for connection to establish

# --- Define simulated devices ---

DEVICES = [
    {"id": "meter-001", "base_voltage": 230.0, "base_current": 4.2},
    {"id": "meter-002", "base_voltage": 228.5, "base_current": 6.1},
    {"id": "meter-003", "base_voltage": 231.0, "base_current": 2.8},
]

# --- Helper function to simulate realistic readings ---

def simulate_reading(device):
    """
    Generate a realistic telemetry reading for a device.
    We add small random variations to make it look like real sensor data.
    """
    voltage = round(device["base_voltage"] + random.uniform(-2.0, 2.0), 2)
    current = round(device["base_current"] + random.uniform(-0.5, 0.5), 2)
    power = round(voltage * current, 2)          # P = V × I (from the lecture!)
    energy = round(random.uniform(10.0, 50.0), 3)  # accumulated kWh
    power_factor = round(random.uniform(0.85, 0.98), 2)
    frequency = round(50.0 + random.uniform(-0.1, 0.1), 2)  # Indonesian grid = 50Hz

    return {
        "device_id": device["id"],
        "voltage": voltage,
        "current": current,
        "power": power,
        "energy": energy,
        "power_factor": power_factor,
        "frequency": frequency,
        "timestamp": time.time()
    }

# --- Main loop: publish every 3 seconds ---

print("\n🚀 Starting simulation... Press Ctrl+C to stop.\n")

try:
    while True:
        for device in DEVICES:
            reading = simulate_reading(device)

            # Convert to JSON string (this is the "message" sent over MQTT)
            payload = json.dumps(reading)

            # Publish to the broker
            topic = f"{MQTT_TOPIC}/{device['id']}"
            client.publish(topic, payload, qos=1)

            print(f"📊 [{reading['device_id']}] "
                  f"V={reading['voltage']}V | "
                  f"I={reading['current']}A | "
                  f"P={reading['power']}W | "
                  f"PF={reading['power_factor']}")

        print(f"   ⏳ Waiting 3 seconds...\n")
        time.sleep(3)

except KeyboardInterrupt:
    print("\n🛑 Simulation stopped.")
    client.loop_stop()
    client.disconnect()
