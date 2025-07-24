#!/bin/bash
# This script automates the setup of the entire GCP infrastructure for the project.

# --- Configuration ---
UNIQUE_ID="AAU_user_id_cloud_project"

# VM Settings
REGION="europe-west1"
ZONE="europe-west1-b"
EDGE_VM_NAME="edge-instance"
CLOUD_VM_NAME="cloud-instance"
EDGE_MACHINE_TYPE="e2-small"  # A small VM for the edge 
CLOUD_MACHINE_TYPE="e2-medium" # A regular VM for the cloud 
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Storage Settings
INPUT_BUCKET="gs://input-bucket-${UNIQUE_ID}"
PROCESSED_BUCKET="gs://processed-bucket-${UNIQUE_ID}"
RESULTS_BUCKET="gs://results-bucket-${UNIQUE_ID}"

echo "--- Starting GCP Infrastructure Setup ---"

# --- 1. Create Storage Buckets ---
echo "Creating Cloud Storage buckets..."
gcloud storage buckets create $INPUT_BUCKET --location=$REGION
gcloud storage buckets create $PROCESSED_BUCKET --location=$REGION
gcloud storage buckets create $RESULTS_BUCKET --location=$REGION
echo "Buckets created."

# --- 2. Create Firewall Rule  ---
echo "Creating firewall rule to allow SSH..."
gcloud compute firewall-rules create allow-ssh-iap \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=0.0.0.0/0

echo "Firewall rule created."

# --- 3. Create Edge VM ---
echo "Creating Edge VM: ${EDGE_VM_NAME}..."
gcloud compute instances create $EDGE_VM_NAME \
    --zone=$ZONE \
    --machine-type=$EDGE_MACHINE_TYPE \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT
echo "Edge VM created."

# --- 4. Create Cloud VM ---
echo "Creating Cloud VM: ${CLOUD_VM_NAME}..."
gcloud compute instances create $CLOUD_VM_NAME \
    --zone=$ZONE \
    --machine-type=$CLOUD_MACHINE_TYPE \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT
echo "Cloud VM created."

# --- 5. Install Docker on both VMs  ---
echo "Installing Docker on Edge VM..."
gcloud compute scp ./install_docker.sh ${EDGE_VM_NAME}:~/ --zone=$ZONE
gcloud compute ssh $EDGE_VM_NAME --zone=$ZONE --command="chmod +x ~/install_docker.sh && ~/install_docker.sh"

echo "Installing Docker on Cloud VM..."
gcloud compute scp ./install_docker.sh ${CLOUD_VM_NAME}:~/ --zone=$ZONE
gcloud compute ssh $CLOUD_VM_NAME --zone=$ZONE --command="chmod +x ~/install_docker.sh && ~/install_docker.sh"

echo "--- GCP Infrastructure Setup Complete ---"