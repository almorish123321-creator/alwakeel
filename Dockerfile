# Minimal test Dockerfile for Render
FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y nginx redis-server supervisor curl ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack install -g pnpm@10.26.2 \
    && pip install --no-cache-dir uv

WORKDIR /app

# Copy everything needed
COPY backend/ ./backend/
COPY frontend/ ./frontend/
COPY skills/ ./skills/
COPY config.render.yaml ./backend/config.yaml
COPY extensions_config.json ./backend/extensions_config.json
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
    && mkdir -p /app/backend/.deer-flow /var/log/supervisor /run/nginx

# Install backend deps
RUN cd /app/backend && uv sync --extra redis --no-dev

# Install and build frontend
RUN cd /app/frontend && pnpm install --frozen-lockfile && SKIP_ENV_VALIDATION=1 pnpm build

EXPOSE 10000
ENTRYPOINT ["/entrypoint.sh"]
