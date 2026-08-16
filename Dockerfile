# DeerFlow Dockerfile for Render (free plan optimized)
# Uses memory-efficient settings for constrained environments

FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8
ENV NODE_OPTIONS=--max-old-space-size=512

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

# Install backend dependencies first (layer caching)
COPY backend/pyproject.toml backend/uv.lock ./backend/
RUN cd /app/backend && uv sync --extra redis --no-install-project

# Copy full backend
COPY backend/ ./backend/
RUN cd /app/backend && uv sync --extra redis --no-dev

# Install and build frontend (memory-limited)
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd /app/frontend && pnpm install --frozen-lockfile
COPY frontend/ ./frontend/
RUN cd /app/frontend && SKIP_ENV_VALIDATION=1 NODE_OPTIONS=--max-old-space-size=512 pnpm build

# Copy config and support files
COPY skills/ ./skills/
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && mkdir -p /app/backend/.deer-flow /var/log/supervisor /run/nginx

EXPOSE 10000
ENTRYPOINT ["/entrypoint.sh"]
