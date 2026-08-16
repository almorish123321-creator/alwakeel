# Backend-only Dockerfile for Render (test)
FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8

RUN pip install --no-cache-dir uv

WORKDIR /app

COPY backend/ ./backend/
COPY skills/ ./skills/
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json

RUN cd /app/backend && uv sync --extra redis --no-dev

RUN mkdir -p /app/backend/.deer-flow

ENV DEER_FLOW_PROJECT_ROOT=/app
ENV DEER_FLOW_HOME=/app/backend/.deer-flow
ENV DEER_FLOW_CONFIG_PATH=/app/backend/config.yaml
ENV PORT=10000

EXPOSE 10000

CMD ["sh", "-c", "cd /app/backend && PYTHONPATH=. uv run --no-sync uvicorn app.gateway.app:app --host 0.0.0.0 --port 10000"]
