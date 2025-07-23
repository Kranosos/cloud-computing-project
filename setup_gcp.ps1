
# --- Configuration ---
$UNIQUE_ID="gabriele2122" 
$REGION="europe-west1"
$ZONE="europe-west1-b"
$EDGE_VM_NAME="edge-instance"
$CLOUD_VM_NAME="cloud-instance"
$EDGE_MACHINE_TYPE="e2-small"
$CLOUD_MACHINE_TYPE="e2-medium"
$IMAGE_FAMILY="ubuntu-2204-lts"
$IMAGE_PROJECT="ubuntu-os-cloud"

# --- Define Scopes for full Cloud API access ---
$SCOPES = "https://www.googleapis.com/auth/cloud-platform"

Write-Host "--- Starting GCP Infrastructure Setup ---"

# --- 1. Create Firewall Rule ---
Write-Host "Creating firewall rule to allow SSH..."
gcloud compute firewall-rules create allow-ssh-iap --direction=INGRESS --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0 --quiet

# --- 2. Create Edge VM with Correct Scopes ---
Write-Host "Creating Edge VM: ${EDGE_VM_NAME}..."
gcloud compute instances create $EDGE_VM_NAME --zone=$ZONE --machine-type=$EDGE_MACHINE_TYPE --image-family=$IMAGE_FAMILY --image-project=$IMAGE_PROJECT --scopes=$SCOPES
Write-Host "Edge VM created."
Write-Host "Waiting 15 seconds for Edge VM to boot..."
Start-Sleep -Seconds 15

# --- 3. Install Docker on Edge VM ---
Write-Host "Installing Docker on Edge VM..."
gcloud compute scp ./install_docker.sh "${EDGE_VM_NAME}:~/" --zone=$ZONE
gcloud compute ssh $EDGE_VM_NAME --zone=$ZONE --command="chmod +x ~/install_docker.sh && ~/install_docker.sh"

# --- 4. Create Cloud VM with Correct Scopes ---
Write-Host "Creating Cloud VM: ${CLOUD_VM_NAME}..."
gcloud compute instances create $CLOUD_VM_NAME --zone=$ZONE --machine-type=$CLOUD_MACHINE_TYPE --image-family=$IMAGE_FAMILY --image-project=$IMAGE_PROJECT --scopes=$SCOPES
Write-Host "Cloud VM created."
Write-Host "Waiting 15 seconds for Cloud VM to boot..."
Start-Sleep -Seconds 15

# --- 5. Install Docker on Cloud VM ---
Write-Host "Installing Docker on Cloud VM..."
gcloud compute scp ./install_docker.sh "${CLOUD_VM_NAME}:~/" --zone=$ZONE
gcloud compute ssh $CLOUD_VM_NAME --zone=$ZONE --command="chmod +x ~/install_docker.sh && ~/install_docker.sh"

Write-Host "--- GCP Infrastructure Setup Complete ---"