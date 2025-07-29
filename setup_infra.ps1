# File: setup_infra.ps1 (Corrected FINAL VERSION)
$ZONE = "europe-west1-b"
$SCOPES = "https://www.googleapis.com/auth/cloud-platform"
$REMOTE_USER = "Gabriele"

# Helper function for running commands on the VMs
function Invoke-GcloudSshCommand {
    param (
        [string]$Instance,
        [string]$Command
    )
    gcloud compute ssh "${REMOTE_USER}@${Instance}" --zone=$ZONE --command=$Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed on ${Instance}. Halting script."
        exit 1
    }
}

Write-Host "--- Starting One-Time Infrastructure Setup ---"

# --- 1. Clean Up and Create Resources ---
Write-Host "[1/4] Cleaning up old resources and creating new VMs..."
gcloud compute instances delete edge-instance cloud-instance --zone=$ZONE --quiet
gcloud compute firewall-rules delete allow-ssh-iap --quiet
gcloud compute firewall-rules create allow-ssh-iap --direction=INGRESS --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0
gcloud compute instances create edge-instance --zone=$ZONE --machine-type="e2-small" --image-family="ubuntu-2204-lts" --image-project="ubuntu-os-cloud" --scopes=$SCOPES
gcloud compute instances create cloud-instance --zone=$ZONE --machine-type="n2-standard-4" --image-family="ubuntu-2204-lts" --image-project="ubuntu-os-cloud" --scopes=$SCOPES --boot-disk-size=30GB

# --- 2. Manual SSH Handshake (User Action Required) ---
Write-Host "`n--- ACTION REQUIRED ---"
Write-Host "The script will now pause. Please run the following two commands in a NEW terminal:"
Write-Host "1. gcloud compute ssh ${REMOTE_USER}@edge-instance --zone=${ZONE}"
Write-Host "2. gcloud compute ssh ${REMOTE_USER}@cloud-instance --zone=${ZONE}"
Write-Host "Answer 'y' to any prompts, then close the new windows and return here."
Read-Host -Prompt "Press Enter to continue AFTER you have completed the SSH steps..."

# --- 3. Install Dependencies and Set Permissions ---
Write-Host "[3/4] Installing dependencies and setting permissions on VMs..."
$INSTALL_COMMAND = "sudo apt-get update -y && sudo apt-get install -y git git-lfs && curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $INSTALL_COMMAND
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $INSTALL_COMMAND
$PERMISSION_COMMAND = "sudo usermod -aG docker ${REMOTE_USER}"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $PERMISSION_COMMAND
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $PERMISSION_COMMAND

# --- 4. NEW: Pre-authorize SSH connection from Edge to Cloud ---
Write-Host "[4/4] Pre-authorizing SSH from Edge to Cloud..."
# Generate a new, passwordless SSH key on the edge-instance
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ''"
# Get the public key content from the edge-instance
$EdgePubKey = (gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command="cat ~/.ssh/id_rsa.pub")
# Append the edge-instance's public key to the cloud-instance's authorized keys file
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "echo '${EdgePubKey}' >> ~/.ssh/authorized_keys"

Write-Host "--- Infrastructure Setup Complete ---"