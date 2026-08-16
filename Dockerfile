# DeerFlow Full Stack for Render (Pre-built Frontend)
FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8
ENV NEXT_TELEMETRY_DISABLED=1
ENV DEER_FLOW_PROJECT_ROOT=/app
ENV DEER_FLOW_HOME=/app/backend/.deer-flow
ENV DEER_FLOW_CONFIG_PATH=/app/backend/config.yaml
ENV DEER_FLOW_EXTENSIONS_CONFIG_PATH=/app/backend/extensions_config.json
ENV CI=true

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx redis-server supervisor curl ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable && corepack install -g pnpm@10.26.2 \
    && pip install --no-cache-dir uv

WORKDIR /app

# Install backend
COPY backend/ ./backend/
COPY skills/ ./skills/
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json
RUN cd /app/backend && uv sync --extra redis --no-dev && mkdir -p /app/backend/.deer-flow

# Install frontend production deps (no build needed - .next is pre-built)
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd /app/frontend && pnpm install --frozen-lockfile --prod
COPY frontend/public ./frontend/public/
COPY frontend/.next ./frontend/.next/
COPY frontend/next.config.js ./frontend/

# Copy runtime configs
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && mkdir -p /var/log/supervisor /run/nginx

EXPOSE 10000
ENTRYPOINT ["/entrypoint.sh"]
