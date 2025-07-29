# File: run_workflow.ps1 (FINAL DIAGNOSTIC VERSION)
param (
    [string]$VideoPath,
    [string]$Effect,
    [string]$GitRepoUrl,
    [string]$UserID 
)
$ZONE = "europe-west1-b"
$REMOTE_USER = "Gabriele"
$PROJECT_ID = "iot-cloud-computing-project"
$REMOTE_PROJECT_PATH = "/home/Gabriele/cloud-computing-project_${UserID}"
$VIDEO_FILENAME = (Get-Item $VideoPath).Name

function Invoke-GcloudSshCommand {
    param (
        [string]$Instance,
        [string]$Command,
        [string]$Checkpoint
    )
    Write-Host "--- CHECKPOINT ${Checkpoint}: About to execute on ${Instance}..."
    gcloud compute ssh "${REMOTE_USER}@${Instance}" --zone=$ZONE --project=$PROJECT_ID --command=$Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "--- FAILED AT CHECKPOINT ${Checkpoint} ---"
        exit 1
    }
    Write-Host "--- CHECKPOINT ${Checkpoint}: Success ---"
}

Write-Host "--- Starting Application Workflow for User ${UserID} ---"

# Step 1
Write-Host "[1/4] Deploying code and inputs..."
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH" -Checkpoint "1A"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH" -Checkpoint "1B"
$DEPLOY_COMMAND = "GIT_LFS_SKIP_SMUDGE=1 git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && mkdir -p storage/input storage/processed storage/results"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $DEPLOY_COMMAND -Checkpoint "1C"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $DEPLOY_COMMAND -Checkpoint "1D"
Write-Host "--- CHECKPOINT 1E: About to SCP video..."
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:${REMOTE_PROJECT_PATH}/storage/input" --zone=$ZONE --project=$PROJECT_ID
if ($LASTEXITCODE -ne 0) { Write-Error "--- FAILED AT CHECKPOINT 1E ---"; exit 1 }
Write-Host "--- CHECKPOINT 1E: Success ---"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt" -Checkpoint "1F"

# Step 2
Write-Host "[2/4] Processing video on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose up video-processor"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $EDGE_DOCKER_COMMAND -Checkpoint "2A"

# Step 3
Write-Host "[3/4] Recognizing flowers and matching dataset on Cloud VM..."
$CLOUD_IP = (gcloud compute instances describe cloud-instance --zone=$ZONE --format='get(networkInterfaces[0].networkIP)' --project=$PROJECT_ID)
$SCP_COMMAND = "scp -r -o StrictHostKeyChecking=no ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_IP}:${REMOTE_PROJECT_PATH}/storage/processed/"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $SCP_COMMAND -Checkpoint "3A"
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose up flower-recognizer && docker compose up dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $CLOUD_DOCKER_COMMAND -Checkpoint "3B"

# Step 4
Write-Host "`n--- ✅ Final Result ---"
$LOGS_COMMAND = "cd ${REMOTE_PROJECT_PATH}; docker compose logs --no-log-prefix --tail='20' dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $LOGS_COMMAND -Checkpoint "4A"

Write-Host "--------------------"
Write-Host "--- Workflow Complete ---"