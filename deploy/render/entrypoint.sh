#!/bin/sh
set -e

PORT=${PORT:-10000}
sed "s/__RENDER_PORT__/${PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
