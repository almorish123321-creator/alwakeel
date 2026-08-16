# Combined Dockerfile for Render deployment (single container)
# Includes: Nginx + Frontend (Next.js) + Backend (FastAPI) + Redis

# ── Stage 1: Build Frontend ─────────────────────────────────────────────
FROM node:22-alpine AS frontend-builder
ARG NPM_REGISTRY
RUN if [ -n "${NPM_REGISTRY}" ]; then \
      export COREPACK_NPM_REGISTRY="${NPM_REGISTRY}"; \
    fi && \
    corepack enable && corepack install -g pnpm@10.26.2
WORKDIR /app
COPY frontend ./frontend
RUN cd /app/frontend && \
    if [ -n "${NPM_REGISTRY}" ]; then pnpm config set registry "${NPM_REGISTRY}"; fi && \
    pnpm install --frozen-lockfile && \
    SKIP_ENV_VALIDATION=1 pnpm build

# ── Stage 2: Build Backend ──────────────────────────────────────────────
FROM ghcr.io/astral-sh/uv:0.11.1 AS uv-source

FROM python:3.12-slim-bookworm AS backend-builder
ARG UV_INDEX_URL
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git build-essential gnupg ca-certificates \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
COPY --from=uv-source /uv /uvx /usr/local/bin/
WORKDIR /app
COPY backend ./backend
RUN --mount=type=cache,target=/root/.cache/uv \
    sh -c 'cd backend && UV_INDEX_URL=${UV_INDEX_URL:-https://pypi.org/simple} uv sync --locked --extra redis'

# ── Stage 3: Final combined image ────────────────────────────────────────
FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8

# Install runtime dependencies: nginx, redis, supervisord, node
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    redis-server \
    supervisor \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js runtime
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm for frontend runtime
RUN corepack enable && corepack install -g pnpm@10.26.2

# Install uv for backend runtime
COPY --from=uv-source /uv /uvx /usr/local/bin/

# Set working directory
WORKDIR /app

# Copy backend with pre-built virtualenv
COPY --from=backend-builder /app/backend ./backend

# Copy frontend with pre-built output
COPY --from=frontend-builder /app/frontend ./frontend

# Copy skills directory
COPY skills ./skills

# Copy nginx config template
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf.template

# Copy supervisord config
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy startup script
COPY deploy/render/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy backend config (minimal render config)
COPY config.render.yaml /app/backend/config.yaml

# Create necessary directories
RUN mkdir -p /app/backend/.deer-flow \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /run/nginx

# Expose port (Render sets PORT env var, nginx will listen on it)
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://127.0.0.1:${PORT:-10000}/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
