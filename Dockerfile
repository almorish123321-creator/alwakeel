# DeerFlow for Render Free Plan - Chat UI + Backend + Redis + Nginx
FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8
ENV DEER_FLOW_PROJECT_ROOT=/app
ENV DEER_FLOW_HOME=/app/backend/.deer-flow
ENV DEER_FLOW_CONFIG_PATH=/app/backend/config.yaml
ENV DEER_FLOW_EXTENSIONS_CONFIG_PATH=/app/backend/extensions_config.json
ENV DEER_FLOW_AUTH_DISABLED=1
ENV CI=true

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-server nginx supervisor curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv

WORKDIR /app

# --- Backend ---
COPY backend/ ./backend/
COPY skills/ ./skills/
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json
RUN cd /app/backend && uv sync --extra redis --no-dev && mkdir -p /app/backend/.deer-flow/data /app/backend/.deer-flow/users/default/agents/default

# Create default agent config
RUN printf 'name: default\ndescription: Default DeerFlow agent\nmodel: gpt-4o-mini\n' > /app/backend/.deer-flow/users/default/agents/default/config.yaml

# --- Chat UI + Nginx + Supervisor config ---
COPY deploy/render/chat.html /app/deploy/render/chat.html
COPY deploy/render/nginx.conf.template /etc/nginx/nginx.conf.template
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 10000

CMD ["/app/entrypoint.sh"]
