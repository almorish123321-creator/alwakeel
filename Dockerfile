# Simplified Dockerfile for Render deployment
# Single container with: Nginx + Frontend + Backend + Redis

FROM python:3.12-slim-bookworm AS base

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8

# Install all system dependencies at once
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

# Copy backend source and install dependencies
COPY backend/pyproject.toml backend/uv.lock ./backend/
RUN cd backend && uv sync --locked --extra redis --no-install-project

# Copy full backend source
COPY backend/ ./backend/
RUN cd backend && uv sync --locked --extra redis --no-dev

# Copy and build frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd frontend && pnpm install --frozen-lockfile
COPY frontend/ ./frontend/
RUN cd frontend && SKIP_ENV_VALIDATION=1 pnpm build

# Copy remaining files
COPY skills ./skills
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && mkdir -p /app/backend/.deer-flow /var/log/supervisor /run/nginx

EXPOSE 10000
ENTRYPOINT ["/entrypoint.sh"]
