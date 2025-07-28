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

# --- 1. Deploy Code ---
Write-Host "[1/5] Deploying project code..."
$GIT_COMMAND = "sudo rm -rf $REMOTE_PROJECT_PATH; git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && git lfs pull && mkdir -p storage/input storage/processed storage/results"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$GIT_COMMAND
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$GIT_COMMAND

# --- 2. Upload Inputs ---
Write-Host "[2/5] Uploading video and effect files..."
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:~/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command="mv ~/$VIDEO_FILENAME ${REMOTE_PROJECT_PATH}/storage/input/"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- 3. Run Video Processor ---
Write-Host "[3/5] Running video processor on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$EDGE_DOCKER_COMMAND

# --- 4. Fix Permissions and Transfer Keyframes ---
Write-Host "[4/5] Fixing permissions and transferring keyframes..."
# This command changes ownership of the new files from 'root' to 'Gabriele'
$CHOWN_COMMAND = "sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_PROJECT_PATH}/storage/processed"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$CHOWN_COMMAND

# Now that permissions are fixed, the transfer will work
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=$ZONE"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$SCP_COMMAND

# --- 5. Run Final Services Sequentially ---
Write-Host "[5/5] Running recognition and matching on Cloud VM..."
# First, run the flower-recognizer and wait for it to complete.
$RECOGNIZER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build flower-recognizer"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$RECOGNIZER_COMMAND

# Second, after the recognizer is done, run the dataset-matcher.
$MATCHER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build dataset-matcher"
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$MATCHER_COMMAND

Write-Host "--- Workflow Complete ---"