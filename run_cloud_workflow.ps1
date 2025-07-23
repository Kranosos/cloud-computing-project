param (
    [string]$VideoPath,
    [string]$Effect,
    [string]$GitRepoUrl
)

# --- Configuration ---
$ZONE = "europe-west1-b"
$EDGE_VM_NAME = "edge-instance"
$CLOUD_VM_NAME = "cloud-instance"
$REMOTE_USER = "Gabriele"
$REMOTE_PROJECT_PATH = "/home/Gabriele/cloud-computing-project"

Write-Host "--- Starting Flower Finder Cloud Workflow ---"

# --- Step 1: Deploy Code via Git ---
Write-Host "[1/6] Deploying project code to both VMs via Git..."
$GIT_COMMAND = "sudo apt-get update -y && sudo apt-get install -y git git-lfs && rm -rf $REMOTE_PROJECT_PATH && git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && git lfs pull"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$GIT_COMMAND
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command=$GIT_COMMAND

# --- Step 2. Upload Inputs ---
Write-Host "[2/6] Uploading video to Edge VM and effect to Cloud VM..."
gcloud compute scp $VideoPath "${REMOTE_USER}@${EDGE_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- Step 3. Run Video Processor on Edge ---
Write-Host "[3/6] Starting video processing on the Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$EDGE_DOCKER_COMMAND

# --- Step 3.5: Fix Permissions on Edge VM ---
Write-Host "[4/6] Fixing permissions on processed keyframes..."
$CHOWN_COMMAND = "sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_PROJECT_PATH}/storage/processed"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$CHOWN_COMMAND

# --- Step 4. Transfer Keyframes from Edge to Cloud ---
Write-Host "[5/6] Transferring processed keyframes from Edge to Cloud..."
$SCP_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=${ZONE}"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$SCP_COMMAND

# --- Step 5. Run Recognizer and Matcher on Cloud ---
Write-Host "[6/6] Starting flower recognition and matching on the Cloud VM..."
Write-Host "The final output will be displayed below:"
$CLOUD_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose down; sudo docker-compose up --build flower-recognizer dataset-matcher"
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command=$CLOUD_DOCKER_COMMAND

Write-Host "--- Workflow Complete ---"