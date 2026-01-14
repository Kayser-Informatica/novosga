#!/bin/bash
set -e

echo "Pre-deployment script for Coolify"
echo "Copying build-time.env to novosga/.env"

# Check if build-time.env exists
if [ ! -f "/artifacts/build-time.env" ]; then
    echo "Warning: build-time.env not found. Skipping copy."
    exit 0
fi

# Copy build-time.env to novosga/.env
cp build-time.env novosga/.env

echo "Successfully copied build-time.env to novosga/.env"
