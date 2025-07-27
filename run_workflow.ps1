# File: run_workflow.ps1 (Final Corrected Version)
param (
    [string]$VideoPath,
    [string]$Effect,
    [string]$GitRepoUrl
)
$ZONE = "europe-west1-b"
$REMOTE_USER = "Gabriele"
$REMOTE_PROJECT_PATH = "/home/Gabriele/cloud-computing-project"
$VIDEO_FILENAME = (Get-Item $VideoPath).Name

Write-Host "--- Starting Application Workflow ---"

# --- 1. Deploy Code and Inputs ---
Write-Host "[1/4] Deploying code and inputs..."
$GIT_COMMAND = "rm -rf $REMOTE_PROJECT_PATH; git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && git lfs pull"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$GIT_COMMAND
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$GIT_COMMAND

# Corrected, more robust file upload
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:/home/Gabriele/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command="mv /home/Gabriele/$VIDEO_FILENAME ${REMOTE_PROJECT_PATH}/storage/input/"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- 2. Run Video Processor ---
Write-Host "[2/4] Running video processor on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$EDGE_DOCKER_COMMAND

# --- 3. Transfer Keyframes ---
Write-Host "[3/4] Transferring keyframes to Cloud VM..."
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=$ZONE"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$SCP_COMMAND

# --- 4. Run Final Services ---
Write-Host "[4/4] Running recognition and matching on Cloud VM..."
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build flower-recognizer dataset-matcher"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$CLOUD_DOCKER_COMMAND

Write-Host "--- Workflow Complete ---"