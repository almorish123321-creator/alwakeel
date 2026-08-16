# DeerFlow Backend for Render - Direct venv activation
FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8
ENV DEER_FLOW_PROJECT_ROOT=/app
ENV DEER_FLOW_HOME=/app/backend/.deer-flow
ENV DEER_FLOW_CONFIG_PATH=/app/backend/config.yaml
ENV DEER_FLOW_EXTENSIONS_CONFIG_PATH=/app/backend/extensions_config.json
ENV CI=true

RUN pip install --no-cache-dir uv

WORKDIR /app

COPY backend/ ./backend/
COPY skills/ ./skills/
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json

RUN cd /app/backend && uv sync --extra redis --no-dev && mkdir -p /app/backend/.deer-flow

COPY deploy/render/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 10000
CMD ["/start.sh"]
