# File: run_workflow.ps1 (FINAL VERSION)
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
    # This function will be quieter in the final version
    gcloud compute ssh "${REMOTE_USER}@${Instance}" --zone=$ZONE --command=$Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed on ${Instance}. Halting script."
        exit 1
    }
}

Write-Host "--- Starting Application Workflow ---"

# --- Steps 1, 2, 3: Cleanup, Deploy, Upload ---
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
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker compose up video-processor"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $EDGE_DOCKER_COMMAND

# --- Step 3: Transfer Keyframes & Run Final Services ---
Write-Host "[3/4] Recognizing flowers and matching dataset on Cloud VM..."
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/ --zone=$ZONE"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $SCP_COMMAND
# Run both services sequentially to get the final result
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker compose up flower-recognizer && sudo docker compose up dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $CLOUD_DOCKER_COMMAND

# --- Step 4: Display the Final Result ---
Write-Host "`n--- Final Result ---"
$LOGS_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker compose logs --no-log-prefix --tail='20' dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $LOGS_COMMAND
Write-Host "--------------------"
Write-Host "--- Workflow Complete ---"