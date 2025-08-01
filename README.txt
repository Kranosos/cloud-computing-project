Flower Finder 

This project is a distributed application designed to recognize flowers in videos and suggest a flower 
to the user based on a desired medicinal effect. It leverages a multi-stage workflow that spans both edge 
and cloud computing resources on Google Cloud Platform (GCP).

System Architecture and Workflow
The application is architected as a three-stage Directed Acyclic Graph (DAG), where the output of one stage 
becomes the input for the next. The system is deployed across two separate GCP virtual machines to simulate 
a real-world edge-to-cloud scenario.

edge-instance: A lightweight VM responsible for initial data ingestion and pre-processing.

cloud-instance: A more powerful VM that handles computationally intensive machine learning and data matching 
tasks.



The workflow is as follows:

Video Processing (on Edge): A video is uploaded to the edge-instance. The video-processor service extracts 
significant still images (keyframes), reducing the data size.

Flower Recognition (on Cloud): The keyframes are transferred to the cloud-instance. The flower-recognizer 
service uses a pre-trained machine learning model (MobileNetV2) to identify flowers in the images.

Dataset Matching (on Cloud): The list of recognized flowers is passed to the dataset-matcher service, which
 cross-references them with a plant dataset to find a flower that matches the user's desired medicinal effect.



Prerequisites
Before you begin, ensure you have the following installed and configured:

A Google Cloud Platform (GCP) account with billing enabled.

The gcloud CLI installed and authenticated (gcloud auth login).

Git and Git LFS.

PowerShell (for running the automation scripts on Windows).

Anaconda/Miniconda with a Conda environment created from the provided environment.yml file.

Locust for load testing (pip install locust).



Setup Instructions (One-Time)
This process provisions and configures all the necessary cloud infrastructure on GCP.

Clone the Repository

git clone https://github.com/Kranosos/cloud-computing-project.git
cd <your-project-directory>


Set Your GCP Project
Open a terminal and set the gcloud CLI to use your GCP project.


gcloud config set project YOUR_PROJECT_ID
Run the Infrastructure Setup Script
Execute the setup_infra.ps1 script from a PowerShell terminal. This script will automatically:



Create the edge-instance and cloud-instance VMs.

Set up firewall rules.

Install Docker, Docker Compose, and other dependencies on both VMs.

Configure secure, passwordless communication between the two VMs.

from the PowerShell:

./setup_infra.ps1
Perform Manual SSH Handshake
The script will pause and ask you to perform a one-time manual SSH connection to each new VM. This is 
required to add their fingerprints to your known hosts.

Open a new terminal and run the two gcloud compute ssh commands provided by the script.
Answer y to any prompts.
Once done, you can close the new terminal and press Enter in the original script window to continue.



Running the Application
You can run the application in two ways: a single manual run for demonstration or a multi-user load test 
for performance analysis.

Single Manual Run
To test the workflow with a single video and effect:

Open an Anaconda PowerShell Prompt and activate your Conda environment.

Navigate to the project's root directory.

Execute the run_workflow.ps1 script with your desired parameters.

# Example of a single manual run
./run_workflow.ps1 -VideoPath "./sunflower.mp4" -Effect "Diuretic" -GitRepoUrl 
"https://github.com/Kranosos/cloud-computing-project.git" -UserID "manual_run_01"


Load Testing with Locust
To fulfill the project's performance testing requirement:

Open an Anaconda PowerShell Prompt and activate your Conda environment.

Navigate to the project's root directory.

In the PowerShell prompt, run the following command once to allow script execution for the current session:


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Start the Locust load tester:


locust -f locustfile.py
Open your web browser and go to http://localhost:8089.


Enter the number of users to simulate (e.g., 10) and a spawn rate (e.g., 1), then click "Start swarming".

While the test is running, you can monitor the performance of your VMs on the GCP Monitoring Dashboard.



Project Structure
├── dataset-matcher/
│   ├── Dockerfile
│   ├── database.py
│   └── ...
├── flower-recognizer/
│   ├── Dockerfile
│   ├── recognize_flower.py
│   └── ...
├── video-processor/
│   ├── Dockerfile
│   ├── Video_Processing.py
│   └── ...
├── storage/            # Placeholder for local testing
│   ├── input/
│   ├── processed/
│   └── results/
├── docker-compose.yml  # Defines the application's microservices
├── setup_infra.ps1     # Automation script for creating cloud infrastructure
├── run_workflow.ps1    # Automation script for orchestrating the application
└── locustfile.py       # Script for load testing the application