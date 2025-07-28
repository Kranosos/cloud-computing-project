# File: run_workflow.ps1 (Corrected FINAL VERSION)
param (
    [string]$VideoPath,
    [string]$Effect,
    [string]$GitRepoUrl
)
$ZONE = "europe-west1-b"
$REMOTE_USER = "Gabriele"
$REMOTE_PROJECT_PATH = "/home/Gabriele/cloud-computing-project"

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

Write-Host "--- Starting Application Workflow ---"

# --- Step 1: Deploy and Upload ---
Write-Host "[1/4] Deploying code and inputs..."
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH"
$DEPLOY_COMMAND = "GIT_LFS_SKIP_SMUDGE=1 git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && mkdir -p storage/input storage/processed storage/results"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $DEPLOY_COMMAND
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $DEPLOY_COMMAND
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- Step 2: Run Video Processor ---
Write-Host "[2/4] Processing video on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose up --build video-processor"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $EDGE_DOCKER_COMMAND

# --- Step 3: Transfer Keyframes & Run Final Services ---
Write-Host "[3/4] Recognizing flowers and matching dataset on Cloud VM..."
# Get the internal IP of the cloud-instance
$CLOUD_IP = (gcloud compute instances describe cloud-instance --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')
# Use a direct, pre-authorized scp command from edge to cloud
$SCP_COMMAND = "scp -r -o StrictHostKeyChecking=no ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_IP}:${REMOTE_PROJECT_PATH}/storage/processed/"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $SCP_COMMAND

# Run both services sequentially to get the final result
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose up --build flower-recognizer && docker compose up --build dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $CLOUD_DOCKER_COMMAND

# --- Step 4: Display the Final Result ---
Write-Host "`n--- Final Result ---"
$LOGS_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose logs --no-log-prefix --tail='20' dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $LOGS_COMMAND
Write-Host "--------------------"
Write-Host "--- Workflow Complete ---"