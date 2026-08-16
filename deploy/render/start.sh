#!/bin/sh
set -e

PORT=${PORT:-10000}
LOGFILE=/app/debug.log

echo "=== DeerFlow Backend Startup ===" > $LOGFILE
echo "PORT=$PORT" >> $LOGFILE
echo "Working dir: $(pwd)" >> $LOGFILE
echo "Python: $(python3 --version)" >> $LOGFILE
echo "" >> $LOGFILE

# Start gateway in background, capture output
cd /app/backend
PYTHONPATH=. uv run --no-sync uvicorn app.gateway.app:app --host 0.0.0.0 --port $PORT >> $LOGFILE 2>&1 &
GATEWAY_PID=$!

# Wait a moment then check if it's running
sleep 5
if kill -0 $GATEWAY_PID 2>/dev/null; then
    echo "Gateway started successfully (PID=$GATEWAY_PID)" >> $LOGFILE
    wait $GATEWAY_PID
else
    echo "Gateway FAILED to start!" >> $LOGFILE
    # Serve the log file via HTTP so we can debug
    cd /app
    python3 -c "
import http.server
import os
port = int(os.environ.get('PORT', '10000'))
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        with open('$LOGFILE') as f:
            self.wfile.write(f.read().encode())
    def log_message(self, *a): pass
http.server.HTTPServer(('0.0.0.0', port), H).serve_forever()
" &
    wait
fi
