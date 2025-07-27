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

# --- 1. Deploy Code and Create Directories ---
Write-Host "[1/4] Deploying code and creating directories..."
# This command now creates the necessary storage sub-folders after cloning
$DEPLOY_COMMAND = "rm -rf $REMOTE_PROJECT_PATH; git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && git lfs pull && mkdir -p storage/input storage/processed storage/results"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$DEPLOY_COMMAND
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command=$DEPLOY_COMMAND

# --- 2. Upload Inputs ---
Write-Host "[2/4] Uploading video and effect files..."
gcloud compute scp $VideoPath "${REMOTE_USER}@edge-instance:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@cloud-instance" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- 3. Run Video Processor ---
Write-Host "[3/4] Running video processor on Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$EDGE_DOCKER_COMMAND

# --- 4. Transfer Keyframes and Run Final Services ---
Write-Host "[4/4] Transferring keyframes and running final services..."
$CLOUD_WORKFLOW_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@cloud-instance:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=${ZONE}; cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build flower-recognizer dataset-matcher"
gcloud compute ssh "${REMOTE_USER}@edge-instance" --zone=$ZONE --command=$CLOUD_WORKFLOW_COMMAND

Write-Host "--- Workflow Complete ---"