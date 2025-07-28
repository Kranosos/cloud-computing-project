# File: run_workflow.ps1 (Definitive Final Version)
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

# --- 1. Clean Up and Deploy Code ---
Write-Host "[1/4] Cleaning, deploying code, and creating directories..."
# This command now uses 'sudo' to fix permission errors during cleanup, then clones and creates all necessary sub-folders.
$DEPLOY_COMMAND = "sudo rm -rf $REMOTE_PROJECT_PATH; git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && git lfs pull && mkdir -p storage/input storage/processed storage/results"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$DEPLOY_COMMAND
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$DEPLOY_COMMAND

# --- 2. Upload Inputs ---
Write-Host "[2/4] Uploading video and effect files..."
# Using a more reliable two-step upload process
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:~/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command="mv ~/$VIDEO_FILENAME ${REMOTE_PROJECT_PATH}/storage/input/"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- 3. Run Video Processor ---
Write-Host "[3/4] Running video processor on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$EDGE_DOCKER_COMMAND

# --- 4. Transfer Keyframes and Run Final Services ---
Write-Host "[4/4] Transferring keyframes and running final services..."
# 4a: Fix permissions on the keyframes created by Docker.
$CHOWN_COMMAND = "sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_PROJECT_PATH}/storage/processed"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$CHOWN_COMMAND

# 4b: Transfer the keyframes now that permissions are correct.
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=$ZONE"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$SCP_COMMAND

# 4c: Run the flower-recognizer and wait for it to complete.
$RECOGNIZER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build flower-recognizer"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$RECOGNIZER_COMMAND

# 4d: Finally, run the dataset-matcher to get the correct result.
$MATCHER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build dataset-matcher"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$MATCHER_COMMAND

Write-Host "--- Workflow Complete ---"