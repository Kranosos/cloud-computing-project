# dataset-matcher/Dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY database.py .
COPY pfaf_plants_merged.csv .

CMD ["python", "database.py"]