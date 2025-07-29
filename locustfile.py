# File: locustfile.py (FINAL VERSION)
import subprocess
import time
from locust import User, task, between

class WorkflowUser(User):
    wait_time = between(10, 20)

    @task
    def run_full_workflow(self):
        video_path = "./sunflower.mp4"
        effect = "Diuretic"
        git_repo_url = "https://github.com/Kranosos/cloud-computing-project.git"

        command_string = (
            f'pwsh ./run_workflow.ps1 -VideoPath "{video_path}" '
            f'-Effect "{effect}" -GitRepoUrl "{git_repo_url}"'
        )

        start_time = time.time()
        try:
            process = subprocess.run(
                command_string,
                capture_output=True,
                text=True,
                check=True,
                shell=True,
                # Use the correct encoding for your console
                encoding='cp850'
            )
            total_time = int((time.time() - start_time) * 1000)
            self.environment.events.request.fire(
                request_type="workflow", name="full_workflow",
                response_time=total_time, response_length=len(process.stdout)
            )
        except subprocess.CalledProcessError as e:
            total_time = int((time.time() - start_time) * 1000)
            # This block will print the hidden error message if the script fails internally
            print("--- SCRIPT FAILED ---")
            print(f"RETURN CODE: {e.returncode}")
            print("\n--- STANDARD OUTPUT FROM SCRIPT ---")
            print(e.stdout)
            print("\n--- STANDARD ERROR FROM SCRIPT ---")
            print(e.stderr)
            print("-----------------------")
            
            self.environment.events.request.fire(
                request_type="workflow", name="full_workflow",
                response_time=total_time, response_length=0, exception=e
            )