#!/usr/bin/env bash

# Exit immediately if a command fails
set -e

echo "🚀 Starting Homelab Deployment..."

createIAMUser() {
    echo -n "👷‍♂️ Creating IAM user: "
    bash scripts/createiamuser.sh
    echo "DONE"
    sleep 1
}

buildingAWSInfrastructure() {
    echo "🏗️ Running Terraform: "
    terraform -chdir=terraform init
    terraform -chdir=terraform apply -auto-approve
    echo "DONE"
    sleep 1
}

generateENVFile() {
    echo -n "🔑 Setting up environment and keys: "
    bash scripts/setup-env.sh
    if [ -f ".env" ]; then
        mv .env docker/.env
    fi
    echo "DONE"
    sleep 1
}

createIAMUser
buildingAWSInfrastructure
generateENVFile

echo "✅ Deployment Complete!"