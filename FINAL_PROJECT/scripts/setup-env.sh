#!/usr/bin/env bash

KEY_PATH="$HOME/.ssh/ec2-sshkey_gitlab.homelab"
ENV_FILE=".env"

# Generate the key silently if it doesn't exist
if [ ! -f "$KEY_PATH" ]; then
    echo "[+] Generating new SSH key..."
    ssh-keygen -t ed25519 -N "" -f "$KEY_PATH" -C "ec2-sshkey"
else
    echo "[+] SSH key already exists."
fi

PUB_KEY=$(cat "${KEY_PATH}.pub")

echo "AUTHORIZED_KEY=$PUB_KEY" > "$ENV_FILE"
echo "[+] .env file updated with your public key."
