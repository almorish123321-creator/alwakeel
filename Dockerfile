# Ultra-minimal test - verify Render Docker builds work
FROM python:3.12-slim-bookworm
WORKDIR /app
EXPOSE 10000
RUN echo 'from http.server import *' > s.py && echo 'class H(BaseHTTPRequestHandler):' >> s.py && echo '  def do_GET(self): self.send_response(200); self.end_headers(); self.wfile.write(b"DeerFlow OK")' >> s.py && echo 'HTTPServer(("0.0.0.0",10000),H).serve_forever()' >> s.py
CMD ["python", "s.py"]
