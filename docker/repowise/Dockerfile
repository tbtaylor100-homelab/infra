FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends git curl jq \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir repowise==0.2.2

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

VOLUME /data
EXPOSE 7338

ENTRYPOINT ["/app/entrypoint.sh"]
