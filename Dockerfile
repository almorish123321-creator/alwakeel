# Combined Dockerfile for Render deployment (single container)
# Includes: Nginx + Frontend (Next.js) + Backend (FastAPI) + Redis

# ── Stage 1: Build Frontend ─────────────────────────────────────────────
FROM node:22-alpine AS frontend-builder
RUN corepack enable && corepack install -g pnpm@10.26.2
WORKDIR /app
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd /app/frontend && pnpm install --frozen-lockfile
COPY frontend ./frontend
RUN cd /app/frontend && SKIP_ENV_VALIDATION=1 pnpm build

# ── Stage 2: Build Backend ──────────────────────────────────────────────
FROM python:3.12-slim-bookworm AS backend-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git build-essential gnupg ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir uv
WORKDIR /app
COPY backend ./backend
RUN cd backend && uv sync --locked --extra redis

# ── Stage 3: Final combined image ────────────────────────────────────────
FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    redis-server \
    supervisor \
    curl \
    ca-certificates \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm and uv
RUN corepack enable && corepack install -g pnpm@10.26.2
RUN pip install --no-cache-dir uv

WORKDIR /app

# Copy pre-built components
COPY --from=backend-builder /app/backend ./backend
COPY --from=frontend-builder /app/frontend ./frontend
COPY skills ./skills
COPY config.render.yaml /app/backend/config.yaml
COPY extensions_config.json /app/backend/extensions_config.json

# Copy configs
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create necessary directories
RUN mkdir -p /app/backend/.deer-flow /var/log/supervisor /run/nginx

EXPOSE 10000

ENTRYPOINT ["/entrypoint.sh"]
