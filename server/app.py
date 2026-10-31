"""API privada de Surco: baja el audio de un video de YouTube con yt-dlp.

Surco la usa solo como respaldo, cuando YouTube no le entrega el audio al
teléfono. Devuelve el .m4a tal cual; título, portada y letra los pone la app.

Variables de entorno:
  SURCO_API_TOKEN  clave obligatoria; la app la manda como "Authorization: Bearer <clave>"
  PORT             puerto (Railway lo define solo; por defecto 8080)
  MAX_MINUTES      duración máxima aceptada (por defecto 20)
"""

import hmac
import os
import re
import shutil
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import yt_dlp

TOKEN = os.environ.get("SURCO_API_TOKEN", "")
MAX_SECONDS = int(os.environ.get("MAX_MINUTES", "20")) * 60
YOUTUBE = re.compile(r"^https?://(www\.|m\.|music\.)?(youtube\.com|youtu\.be)/")

# ponytail: una descarga a la vez alcanza para un solo usuario; si algún día lo
# usan varios, subir el semáforo y medir RAM/CPU del plan de Railway.
_busy = threading.Semaphore(1)


def download(url: str, folder: str) -> str:
    opts = {
        "format": "bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]",
        "outtmpl": os.path.join(folder, "audio.%(ext)s"),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "match_filter": yt_dlp.utils.match_filter_func(f"duration <= {MAX_SECONDS}"),
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)
        if info is None or info.get("duration", 0) > MAX_SECONDS:
            raise ValueError("Video muy largo o no disponible")
        return ydl.prepare_filename(info)


class Handler(BaseHTTPRequestHandler):
    server_version = "surco-api"

    def _reply(self, code: int, text: str) -> None:
        body = text.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            return self._reply(200, "ok")
        if parsed.path != "/audio":
            return self._reply(404, "no existe")
        auth = self.headers.get("Authorization", "")
        if not hmac.compare_digest(auth.encode(), f"Bearer {TOKEN}".encode()):
            return self._reply(401, "clave incorrecta")
        url = parse_qs(parsed.query).get("url", [""])[0]
        if not YOUTUBE.match(url):
            return self._reply(400, "solo links de YouTube")
        if not _busy.acquire(timeout=120):
            return self._reply(503, "ocupado, intenta en un rato")
        folder = tempfile.mkdtemp()
        try:
            path = download(url, folder)
            size = os.path.getsize(path)
            self.send_response(200)
            self.send_header("Content-Type", "audio/mp4")
            self.send_header("Content-Length", str(size))
            self.end_headers()
            with open(path, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
        except Exception as e:  # yt-dlp lanza varios tipos; al cliente le basta el mensaje
            self._reply(502, f"no se pudo bajar: {e}")
        finally:
            _busy.release()
            shutil.rmtree(folder, ignore_errors=True)

    def log_message(self, fmt: str, *args) -> None:
        # Sin URLs ni claves en los logs: solo método, ruta base y código.
        print(f"{self.command} {urlparse(self.path).path} {args[1] if len(args) > 1 else ''}", flush=True)


if __name__ == "__main__":
    if len(TOKEN) < 24:
        raise SystemExit("Falta SURCO_API_TOKEN (mínimo 24 caracteres)")
    port = int(os.environ.get("PORT", "8080"))
    print(f"surco-api escuchando en {port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
