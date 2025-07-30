# File: run_workflow.ps1 (FINAL and COMPLETE VERSION)
param (
    [string]$VideoPath,
    [string]$Effect,
    [string]$GitRepoUrl,
    [string]$UserID 
)
$ZONE = "europe-west1-b"
$REMOTE_USER = "Gabriele"
$PROJECT_ID = "iot-cloud-computing-project"
$PROJECT_NAME = "flower-finder_${UserID}"
$REMOTE_PROJECT_PATH = "/home/Gabriele/${PROJECT_NAME}"
# Get the base filename from the VideoPath
$VIDEO_FILENAME = (Get-Item $VideoPath).Name

# Helper function to execute commands on remote VMs
function Invoke-GcloudSshCommand {
    param (
        [string]$Instance,
        [string]$Command
    )
    gcloud compute ssh "${REMOTE_USER}@${Instance}" --zone=$ZONE --project=$PROJECT_ID --command=$Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed on ${Instance}. Halting script."
        exit 1
    }
}

Write-Host "--- Starting Application Workflow for User ${UserID} ---"

# --- Step 1: Deploy Code ---
Write-Host "[1/5] Deploying code for User ${UserID}..."
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH; GIT_LFS_SKIP_SMUDGE=1 git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && mkdir -p storage/input storage/processed storage/results"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH; GIT_LFS_SKIP_SMUDGE=1 git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && mkdir -p storage/input storage/processed storage/results"

# --- Step 2: Pre-Build Docker Images to Prevent Timeouts ---
Write-Host "[2/5] Pre-building Docker images..."
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "cd ${REMOTE_PROJECT_PATH}; docker compose --project-name ${PROJECT_NAME} build"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "cd ${REMOTE_PROJECT_PATH}; docker compose --project-name ${PROJECT_NAME} build"

# --- Step 3: Upload Inputs ---
Write-Host "[3/5] Uploading video and effect files..."
Start-Sleep -Seconds 5
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "ls -l ${REMOTE_PROJECT_PATH}/storage/"
# This scp command now includes the explicit destination filename for robustness
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:${REMOTE_PROJECT_PATH}/storage/input/${VIDEO_FILENAME}" --zone=$ZONE --project=$PROJECT_ID
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "cd ${REMOTE_PROJECT_PATH}; mkdir -p storage/results; echo '$Effect' | tee ./storage/results/desired_effect.txt"

# --- Step 4: Run Workflow ---
Write-Host "[4/5] Running workflow tasks..."
$CLOUD_IP = (gcloud compute instances describe cloud-instance --zone=$ZONE --format='get(networkInterfaces[0].networkIP)' --project=$PROJECT_ID)

# Run video processor (no --build needed)
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose --project-name ${PROJECT_NAME} up video-processor"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $EDGE_DOCKER_COMMAND

# Transfer keyframes
$SCP_COMMAND = "scp -r -o StrictHostKeyChecking=no ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_IP}:${REMOTE_PROJECT_PATH}/storage/processed/"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $SCP_COMMAND

# Run cloud services (no --build needed)
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose --project-name ${PROJECT_NAME} up flower-recognizer && docker compose --project-name ${PROJECT_NAME} up dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $CLOUD_DOCKER_COMMAND

# --- Step 5: Display the Final Result ---
Write-Host "`n--- Final Result for User ${UserID} ---"
$LOGS_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose --project-name ${PROJECT_NAME} logs --no-log-prefix --tail='20' dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $LOGS_COMMAND
Write-Host "--------------------"
Write-Host "--- Workflow Complete for User ${UserID} ---"