# File: locustfile.py (FINAL VERSION with Lock File)
import subprocess
import time
import uuid
import os
from locust import User, task, between

# Path for the lock file to prevent race conditions
LOCK_FILE = "locust.lock"

class WorkflowUser(User):
    wait_time = between(2, 5) # Users wait a bit before trying again
    
    def on_start(self):
        # Give each simulated user a unique ID
        self.user_id = str(uuid.uuid4())

    @task
    def run_full_workflow(self):
        # --- Check for lock file ---
        if os.path.exists(LOCK_FILE):
            # If lock file exists, another test is running. Skip this one.
            time.sleep(1) # Wait a second and let this user try again later
            return

        try:
            # --- Create lock file to signal a test is running ---
            with open(LOCK_FILE, "w") as f:
                f.write(self.user_id)

            video_path = "./sunflower.mp4"
            effect = "Diuretic"
            git_repo_url = "https://github.com/Kranosos/cloud-computing-project.git"

            command_string = (
                f'powershell ./run_workflow.ps1 -VideoPath "{video_path}" '
                f'-Effect "{effect}" -GitRepoUrl "{git_repo_url}" '
                f'-UserID "{self.user_id}"'
            )

            start_time = time.time()
            process = subprocess.run(
                command_string,
                capture_output=True, text=True, check=True, shell=True, encoding='cp850'
            )
            total_time = int((time.time() - start_time) * 1000)
            self.environment.events.request.fire(
                request_type="workflow", name="full_workflow",
                response_time=total_time, response_length=len(process.stdout)
            )

        except subprocess.CalledProcessError as e:
            total_time = int((time.time() - start_time) * 1000)
            self.environment.events.request.fire(
                request_type="workflow", name="full_workflow",
                response_time=total_time, response_length=0, exception=e
            )
        finally:
            # --- IMPORTANT: Always remove the lock file when done ---
            if os.path.exists(LOCK_FILE):
                os.remove(LOCK_FILE)