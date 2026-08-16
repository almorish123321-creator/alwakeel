#!/bin/sh
PORT=${PORT:-10000}
LOGFILE=/app/debug.log

echo "=== Startup Debug ===" > $LOGFILE
echo "PORT=$PORT" >> $LOGFILE
echo "PWD=$(pwd)" >> $LOGFILE
echo "Python=$(python3 --version 2>&1)" >> $LOGFILE
echo "Files in /app/backend:" >> $LOGFILE
ls /app/backend/ >> $LOGFILE 2>&1
echo "Venv check:" >> $LOGFILE
ls /app/backend/.venv/bin/python 2>&1 >> $LOGFILE
echo "" >> $LOGFILE

# Try to start gateway and capture ALL output
cd /app/backend
PYTHONPATH=. /app/backend/.venv/bin/python -m uvicorn app.gateway.app:app --host 0.0.0.0 --port $PORT >> $LOGFILE 2>&1 &
PID=$!

# Give it time to start or crash
sleep 8

if kill -0 $PID 2>/dev/null; then
    echo "Gateway running PID=$PID" >> $LOGFILE
    wait $PID
else
    echo "Gateway crashed!" >> $LOGFILE
fi

# If we get here, serve the log
cd /app
python3 -c "
import http.server, os
port = int(os.environ.get('PORT', '10000'))
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        try:
            with open('/app/debug.log') as f:
                self.wfile.write(f.read().encode())
        except: self.wfile.write(b'No log file')
    def log_message(self, *a): pass
http.server.HTTPServer(('0.0.0.0', port), H).serve_forever()
"
