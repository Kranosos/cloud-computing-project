
param (
    [string]$VideoPath,
    [string]$Effect
)

# --- Configuration ---
$ZONE = "europe-west1-b"
$EDGE_VM_NAME = "edge-instance"
$CLOUD_VM_NAME = "cloud-instance"
$REMOTE_USER = "Gabriele"
$REMOTE_PROJECT_PATH = "~/cloud-computing-project"

Write-Host "--- Starting Flower Finder Cloud Workflow ---"

# --- 1. Deploy Project Code to VMs ---
Write-Host "[1/5] Deploying project code to both VMs..."
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command="mkdir -p ${REMOTE_PROJECT_PATH}"
gcloud compute scp --recurse . "${REMOTE_USER}@${EDGE_VM_NAME}:${REMOTE_PROJECT_PATH}/" --zone=$ZONE

gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="mkdir -p ${REMOTE_PROJECT_PATH}"
gcloud compute scp --recurse . "${REMOTE_USER}@${CLOUD_VM_NAME}:${REMOTE_PROJECT_PATH}/" --zone=$ZONE

# --- 2. Upload Inputs ---
Write-Host "[2/5] Uploading video to Edge VM and effect to Cloud VM..."
gcloud compute scp $VideoPath "${REMOTE_USER}@${EDGE_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- 3. Run Video Processor on Edge ---
Write-Host "[3/5] Starting video processing on the Edge VM..."
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command="cd ${REMOTE_PROJECT_PATH}; docker-compose up --build -d video-processor"

# --- 4. Transfer Keyframes from Edge to Cloud ---
Write-Host "[4/5] Transferring processed keyframes from Edge to Cloud..."
$scp_command = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=${ZONE}"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$scp_command

# --- 5. Run Recognizer and Matcher on Cloud ---
Write-Host "[5/5] Starting flower recognition and matching on the Cloud VM..."
Write-Host "The final output will be displayed below:"
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="cd ${REMOTE_PROJECT_PATH}; docker-compose up --build flower-recognizer dataset-matcher"

Write-Host "--- Workflow Complete ---"