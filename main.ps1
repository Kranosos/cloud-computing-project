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
$SCOPES = "https://www.googleapis.com/auth/cloud-platform"

Write-Host "--- Starting Full Project Deployment and Execution ---"

# --- Step 1: Clean Up and Create Infrastructure ---
Write-Host "[1/5] Cleaning up old resources and creating new VMs..."
gcloud compute instances delete $EDGE_VM_NAME $CLOUD_VM_NAME --zone=$ZONE --quiet
gcloud compute firewall-rules delete allow-ssh-iap --quiet
gcloud compute firewall-rules create allow-ssh-iap --direction=INGRESS --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0
gcloud compute instances create $EDGE_VM_NAME --zone=$ZONE --machine-type="e2-small" --image-family="ubuntu-2204-lts" --image-project="ubuntu-os-cloud" --scopes=$SCOPES
gcloud compute instances create $CLOUD_VM_NAME --zone=$ZONE --machine-type="e2-medium" --image-family="ubuntu-2204-lts" --image-project="ubuntu-os-cloud" --scopes=$SCOPES --boot-disk-size=30GB

# --- Step 2: Install Dependencies on VMs ---
Write-Host "[2/5] Waiting for VMs to boot and installing dependencies..."
Start-Sleep -Seconds 60
$INSTALL_COMMAND = "sudo apt-get update -y && sudo apt-get install -y git git-lfs docker-compose"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$INSTALL_COMMAND
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command=$INSTALL_COMMAND

# --- Step 3: Deploy Code and Inputs ---
Write-Host "[3/5] Deploying code and uploading inputs..."
$GIT_COMMAND = "rm -rf $REMOTE_PROJECT_PATH && git clone $GitRepoUrl $REMOTE_PROJECT_PATH && cd $REMOTE_PROJECT_PATH && git lfs pull"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$GIT_COMMAND
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command=$GIT_COMMAND

gcloud compute scp $VideoPath "${REMOTE_USER}@${EDGE_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/input/" --zone=$ZONE
gcloud compute ssh "${REMOTE_USER}@${CLOUD_VM_NAME}" --zone=$ZONE --command="echo '$Effect' | tee ${REMOTE_PROJECT_PATH}/storage/results/desired_effect.txt"

# --- Step 4: Run Video Processor on Edge ---
Write-Host "[4/5] Starting video processing on the Edge VM..."
$EDGE_DOCKER_COMMAND = "cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build video-processor"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$EDGE_DOCKER_COMMAND

# --- Step 5: Transfer Keyframes and Run Final Services ---
Write-Host "[5/5] Transferring keyframes and running final services..."
$CLOUD_WORKFLOW_COMMAND = "gcloud compute scp --recurse ${REMOTE_PROJECT_PATH}/storage/processed/* ${REMOTE_USER}@${CLOUD_VM_NAME}:${REMOTE_PROJECT_PATH}/storage/processed/ --zone=${ZONE}; cd ${REMOTE_PROJECT_PATH}; sudo docker-compose up --build flower-recognizer dataset-matcher"
gcloud compute ssh "${REMOTE_USER}@${EDGE_VM_NAME}" --zone=$ZONE --command=$CLOUD_WORKFLOW_COMMAND

Write-Host "--- Workflow Complete ---"