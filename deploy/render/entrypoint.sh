#!/bin/sh
set -e

PORT=${PORT:-10000}

# Generate backend extensions config if not present
cp /app/backend/extensions_config.json 2>/dev/null || echo '{}' > /app/backend/extensions_config.json

# Update nginx config to listen on the correct port and use localhost upstreams
sed -e "s/gateway:8001/127.0.0.1:8001/g" \
    -e "s/frontend:3000/127.0.0.1:3000/g" \
    -e "s/provisioner:8002/127.0.0.1:8002/g" \
    -e "s/listen 2026/listen ${PORT}/g" \
    -e "s/resolver 127.0.0.11 valid=10s ipv6=off;/resolver 127.0.0.1 valid=10s ipv6=off;/g" \
    /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Start all services via supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
