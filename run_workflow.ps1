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
    Write-Host "Executing on ${Instance}: ${Command}"
    gcloud compute ssh "${REMOTE_USER}@${Instance}" --zone=$ZONE --command=$Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed on ${Instance}. Halting script."
        exit 1
    }
}

Write-Host "--- Starting DIAGNOSTIC Workflow ---"

# --- Steps 1, 2, 3: Cleanup, Deploy, Upload (These are working correctly) ---
Write-Host "[1/5] Cleaning up..."
Invoke-GcloudSshCommand -Instance "edge-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "sudo rm -rf $REMOTE_PROJECT_PATH"

Write-Host "[2/5] Deploying code..."
$DEPLOY_COMMAND = "GIT_LFS_SKIP_SMUDGE=1 git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && mkdir -p storage/input storage/processed storage/results"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $DEPLOY_COMMAND
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $DEPLOY_COMMAND

Write-Host "[3/5] Uploading video and effect files..."
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command "echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- Step 4: Run Video Processor (Working correctly) ---
Write-Host "[4/5] Running video processor on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker compose up --build video-processor"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $EDGE_DOCKER_COMMAND

# --- Step 5: Transfer and run final services ONE BY ONE ---
Write-Host "[5/5] Transferring keyframes..."
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/ --zone=$ZONE"
Invoke-GcloudSshCommand -Instance "edge-instance" -Command $SCP_COMMAND

# --- DIAGNOSTIC STEP A: Run Flower Recognizer and show its logs ---
Write-Host "`n--- Running Flower Recognizer (Foreground) ---"
$RECOGNIZER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker compose up --build flower-recognizer"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $RECOGNIZER_COMMAND

# --- DIAGNOSTIC STEP B: Run Dataset Matcher and show its logs ---
Write-Host "`n--- Running Dataset Matcher (Foreground) ---"
$MATCHER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker compose up --build dataset-matcher"
Invoke-GcloudSshCommand -Instance "cloud-instance" -Command $MATCHER_COMMAND

Write-Host "--- Diagnostic Workflow Complete ---"