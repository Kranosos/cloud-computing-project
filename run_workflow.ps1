param (
    [string]$VideoPath,
    [string]$Effect,
    [string]$GitRepoUrl
)
$ZONE = "europe-west1-b"
$REMOTE_USER = "Gabriele"
$REMOTE_PROJECT_PATH = "/home/Gabriele/cloud-computing-project"
$VIDEO_FILENAME = (Get-Item $VideoPath).Name

function Invoke-GcloudSshCommand {
    param (
        [string]$Instance,
        [string]$Command
    )
    Write-Host "Executing on ${Instance}: ${Command}"
    gcloud compute ssh "${REMOTE_USER}@${Instance}" --zone=$ZONE --command=$Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed on ${Instance}. Halting script."
        exit 1
    }
}

Write-Host "--- Starting Application Workflow ---"

# --- 1. Clean Up and Deploy Code ---
Write-Host "[1/5] Cleaning up old project files and results..."
# Clean up both VMs to ensure no stale data is used
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH"

Write-Host "[2/5] Deploying code (without LFS model)..."
# This command now avoids pulling the large LFS file
$DEPLOY_COMMAND = "GIT_LFS_SKIP_SMUDGE=1 git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && mkdir -p storage/input storage/processed storage/results"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $DEPLOY_COMMAND
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $DEPLOY_COMMAND

# --- 2. Upload Inputs ---
Write-Host "[3/5] Uploading video and effect files..."
# Use a more reliable SCP path and verify success
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to upload video file. Halting script."
    exit 1
}
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- 3. Run Video Processor ---
Write-Host "[4/5] Running video processor on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $EDGE_DOCKER_COMMAND

# --- 4. Transfer Keyframes and Run Final Services ---
Write-Host "[5/5] Transferring keyframes and running final services..."
# This SCP now copies the entire processed directory
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/ --zone=$ZONE"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $SCP_COMMAND

# Run the final services. Using -d hides the logs for a cleaner output.
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build -d flower-recognizer dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $CLOUD_DOCKER_COMMAND

# --- 5. Display the Final Result ---
Write-Host "`n--- Fetching Final Result ---"
# Wait a few seconds for the matcher to finish, then print its logs
Start-Sleep -Seconds 10
$LOGS_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose logs dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $LOGS_COMMAND

Write-Host "--- Workflow Complete ---"