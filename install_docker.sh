#!/bin/bash
# This script installs Docker and Docker Compose on a Debian/Ubuntu VM.

# Update package list
sudo apt-get update -y

# Install Docker
sudo apt-get install -y docker.io

# Add current user to the docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt-get install -y docker-compose

echo "Docker and Docker Compose installation complete."