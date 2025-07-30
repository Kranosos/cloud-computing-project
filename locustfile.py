# File: locustfile.py (FINAL - With User ID)
import subprocess
import time
import uuid
from locust import User, task, between

class WorkflowUser(User):
    wait_time = between(10, 20)

    def on_start(self):
        # Give each simulated user a unique ID
        self.user_id = str(uuid.uuid4())

    @task
    def run_full_workflow(self):
        video_path = "./sunflower.mp4"
        effect = "Diuretic"
        git_repo_url = "https://github.com/Kranosos/cloud-computing-project.git"

        command_string = (
            f'powershell ./run_workflow.ps1 -VideoPath "{video_path}" '
            f'-Effect "{effect}" -GitRepoUrl "{git_repo_url}" '
            # Pass the unique user ID to the script
            f'-UserID "{self.user_id}"'
        )

        start_time = time.time()
        try:
            process = subprocess.run(
                command_string,
                capture_output=True,
                text=True,
                check=True,
                shell=True,
                encoding='cp850'
            )
            total_time = int((time.time() - start_time) * 1000)
            self.environment.events.request.fire(
                request_type="workflow", name="full_workflow",
                response_time=total_time, response_length=len(process.stdout)
            )
        except subprocess.CalledProcessError as e:
            total_time = int((time.time() - start_time) * 1000)
            # Log the full error to the Locust terminal if it fails
            error_details = f"STDOUT: {e.stdout} \nSTDERR: {e.stderr}"
            self.environment.events.request.fire(
                request_type="workflow", name="full_workflow",
                response_time=total_time, response_length=0, exception=e
            )