$ZONE = "europe-west1-b"
$SCOPES = "https://www.googleapis.com/auth/cloud-platform"
$REMOTE_USER = "Gabriele"

Write-Host "--- Starting One-Time Infrastructure Setup ---"

# --- 1. Clean Up and Create Resources ---
Write-Host "[1/3] Cleaning up old resources and creating new VMs..."
gcloud compute instances delete edge-instance cloud-instance --zone=$ZONE --quiet
gcloud compute firewall-rules delete allow-ssh-iap --quiet
gcloud compute firewall-rules create allow-ssh-iap --direction=INGRESS --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0
gcloud compute instances create edge-instance --zone=$ZONE --machine-type="e2-small" --image-family="ubuntu-2204-lts" --image-project="ubuntu-os-cloud" --scopes=$SCOPES
gcloud compute instances create cloud-instance --zone=$ZONE --machine-type="e2-medium" --image-family="ubuntu-2204-lts" --image-project="ubuntu-os-cloud" --scopes=$SCOPES --boot-disk-size=30GB

# --- 2. Manual SSH Handshake (User Action Required) ---
Write-Host "`n--- ACTION REQUIRED ---"
Write-Host "The script will now pause. Please run the following two commands in a NEW terminal:"
Write-Host "1. gcloud compute ssh ${REMOTE_USER}@edge-instance --zone=${ZONE}"
Write-Host "2. gcloud compute ssh ${REMOTE_USER}@cloud-instance --zone=${ZONE}"
Write-Host "Answer 'y' to any prompts, then close the new windows and return here."
Read-Host -Prompt "Press Enter to continue AFTER you have completed the SSH steps..."

# --- 3. Install Dependencies ---
Write-Host "[3/3] Installing dependencies on VMs..."
# The old "docker-compose" package has been removed from this command.
# The correct Docker Compose V2 plugin is installed via the install_docker.sh script's method.
$INSTALL_COMMAND = "sudo apt-get update -y && sudo apt-get install -y git git-lfs && curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$INSTALL_COMMAND
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$INSTALL_COMMAND

Write-Host "--- Infrastructure Setup Complete ---"