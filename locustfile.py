# File: locustfile.py
import subprocess
import time
from locust import User, task, between

class WorkflowUser(User):
    # Each simulated user will wait 5 to 15 seconds between runs
    wait_time = between(5, 15)

    @task
    def run_full_workflow(self):
        # --- Parameters for your script ---
        # Ensure the video path is correct on your local machine
        video_path = "./sunflower.mp4"
        # The effect can be changed to test different scenarios
        effect = "Diuretic"
        git_repo_url = "https://github.com/Kranosos/cloud-computing-project.git"

        command = [
            "pwsh", # Use 'powershell' on Windows if pwsh isn't found
            "./run_workflow.ps1",
            "-VideoPath", video_path,
            "-Effect", effect,
            "-GitRepoUrl", git_repo_url
        ]

        start_time = time.time()
        try:
            # Execute the PowerShell script as a subprocess
            # In locustfile.py
            process = subprocess.run(command, capture_output=True, text=True, check=True, shell=True)
            total_time = int((time.time() - start_time) * 1000)
            # Mark the request as successful in Locust
            self.environment.events.request.fire(
                request_type="workflow",
                name="full_workflow",
                response_time=total_time,
                response_length=len(process.stdout)
            )
        except subprocess.CalledProcessError as e:
            total_time = int((time.time() - start_time) * 1000)
            # Mark the request as a failure in Locust
            self.environment.events.request.fire(
                request_type="workflow",
                name="full_workflow",
                response_time=total_time,
                response_length=0,
                exception=e
            )