# flower-recognizer/Dockerfile
FROM python:3.10-slim

# Install the system dependency for OpenCV
RUN apt-get update && apt-get install -y libgl1-mesa-glx libglib2.0-0

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "recognize_flower.py", "/app/storage/processed"]