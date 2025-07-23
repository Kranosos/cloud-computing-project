param (
    [string]$VideoPath,
    [string]$Effect
)

# --- Configuration ---
$ZONE = "europe-west1-b"
$EDGE_VM_NAME = "edge-instance"
$CLOUD_VM_NAME = "cloud-instance"
$REMOTE_USER = "Gabriele"
$REMOTE_PROJECT_PATH = "/home/Gabriele/cloud-computing-project"
$LOCAL_ZIP_FILE = "cloud-computing-project.zip"

Write-Host "--- Starting Flower Finder Cloud Workflow ---"

# --- Step 1: Create Zip and Deploy Code ---
Write-Host "[1/5] Compressing and deploying project code..."
Compress-Archive -Path ".\*" -DestinationPath $LOCAL_ZIP_FILE -Force

# Deploy to Edge VM
gcloud compute scp $LOCAL_ZIP_FILE "${REMOTE_USER}@${EDGE_VM_NAME}:~/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command="sudo apt-get install -y unzip && unzip -o ~/$LOCAL_ZIP_FILE -d $REMOTE_PROJECT_PATH"

# Deploy to Cloud VM
gcloud compute scp $LOCAL_ZIP_FILE "${REMOTE_USER}@${CLOUD_VM_NAME}:~/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="sudo apt-get install -y unzip && unzip -o ~/$LOCAL_ZIP_FILE -d $REMOTE_PROJECT_PATH"

# --- Step 2. Upload Inputs ---
Write-Host "[2/5] Uploading video to Edge VM and effect to Cloud VM..."
gcloud compute scp $VideoPath "${REMOTE_USER}@${EDGE_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- Step 3. Run Video Processor on Edge ---
Write-Host "[3/5] Starting video processing on the Edge VM..."
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command="cd ${REMOTE_PROJECT_PATH}; docker-compose up --build -d video-processor"

# --- Step 4. Transfer Keyframes from Edge to Cloud ---
Write-Host "[4/5] Transferring processed keyframes from Edge to Cloud..."
$scp_command = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=${ZONE}"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$scp_command

# --- Step 5. Run Recognizer and Matcher on Cloud ---
Write-Host "[5/5] Starting flower recognition and matching on the Cloud VM..."
Write-Host "The final output will be displayed below:"
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="cd ${REMOTE_PROJECT_PATH}; docker-compose up --build flower-recognizer dataset-matcher"

Write-Host "--- Workflow Complete ---"