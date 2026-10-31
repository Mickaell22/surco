# surco-api

API privada y opcional para Surco: baja el audio de los videos que YouTube no le
entrega al teléfono. Python + yt-dlp, sin base de datos.

- `GET /health` responde `ok`.
- `GET /audio?url=<link de YouTube>` con `Authorization: Bearer <SURCO_API_TOKEN>`
  devuelve el `.m4a`.
- `GET /info?url=<link de YouTube>` (misma clave) devuelve título, autor,
  duración, miniatura y descripción en JSON, para cuando YouTube no deja leer
  el video desde el teléfono.

Variables: `SURCO_API_TOKEN` (obligatoria, 24+ caracteres), `MAX_MINUTES`
(por defecto 20), `PORT` (Railway la pone sola).

Despliegue en Railway desde esta carpeta: `railway up`. La clave se define con
`railway variables --set SURCO_API_TOKEN=...` y nunca va al repo.
