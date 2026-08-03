from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os
import sys

assets = Path(__file__).resolve().parents[1] / "app" / "src" / "main" / "assets"
port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
os.chdir(assets)
print(f"Open http://127.0.0.1:{port}/player.html")
print("Keyboard: Enter=play/pause, arrows=episode/volume, PageUp/PageDown=channel, 1-4=channel")
ThreadingHTTPServer(("127.0.0.1", port), SimpleHTTPRequestHandler).serve_forever()
