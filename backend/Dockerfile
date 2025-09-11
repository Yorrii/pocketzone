FROM python:3.11-slim

# Užitečné systémové knihovny (časové zóny, certifikáty, ping)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# port pro Flask API
EXPOSE 5001

# Spouštěč: gunicorn (2 workery – na MVP stačí)
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5001", "app:app"]
