FROM python:3.11.8-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libxml2-dev libxslt-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

ENV PORT=8080
EXPOSE 8080

# 2 workers strikes a balance: one worker can't saturate Cloud Run's 1 vCPU
# instance on its own (handlers are sync + I/O-bound on Turso HTTPS calls),
# but more than 2 starves the per-instance memory budget and hurts cold start.
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT} --workers 2
