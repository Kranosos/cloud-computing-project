import subprocess
import time
from locust import User, task, between

class WorkflowUser(User):
    # Wait 5 to 10 seconds between tasks
    wait_time = between(5, 10)

    @task
    def run_full_workflow(self):
        # --- Parameters for your script ---
        video_path = "./sunflower.mp4" # Path to an example video
        effect = "diuretic" # An example effect to test
        git_repo_url = "https://github.com/Gabriele-G/cloud-computing-project.git" # Your Git repo URL

        command = [
            "pwsh", # Use 'powershell' on Windows
            "./run_workflow.ps1",
            "-VideoPath", video_path,
            "-Effect", effect,
            "-GitRepoUrl", git_repo_url
        ]

        start_time = time.time()
        try:
            # Execute the PowerShell script as a subprocess
            process = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True # This will raise an exception if the script fails
            )
            total_time = int((time.time() - start_time) * 1000)
            # Mark the request as successful in Locust
            self.environment.events.request.fire(
                request_type="workflow",
                name="run_workflow.ps1",
                response_time=total_time,
                response_length=len(process.stdout)
            )
        except subprocess.CalledProcessError as e:
            total_time = int((time.time() - start_time) * 1000)
            # Mark the request as a failure in Locust
            self.environment.events.request.fire(
                request_type="workflow",
                name="run_workflow.ps1",
                response_time=total_time,
                response_length=0,
                exception=e
            )