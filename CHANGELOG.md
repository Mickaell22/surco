# Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); las versiones siguen [SemVer](https://semver.org/lang/es/).

## [1.5.0] - 2026-11-01

### Agregado
- Día de Muertos con escena completa: papel picado, pétalos de cempasúchil, mariposas monarca, calaveritas que suben, ofrendas con velas y una calavera de azúcar en la barra.
- Más decoración en las demás temporadas: pinos y nieve acumulada en Navidad, fuegos artificiales en Año Nuevo, guirnaldas propias (corazones, flores, hojas, banderines) y su adorno en la barra. El Día del Padre ahora también tiene decoración.

### Corregido
- "Anterior" desde la notificación o los audífonos reinicia la canción si ya van más de 3 segundos, igual que el botón de la app; tocarlo otra vez va a la anterior.

## [1.4.1] - 2026-10-31

### Corregido
- Descargar de YouTube cuando YouTube limita las peticiones de tu conexión: si el teléfono no puede leer el video y tienes servidor configurado, Surco pide los datos y el audio al servidor.
- Errores de YouTube en español y sin el texto técnico en inglés.

## [1.4.0] - 2026-10-31

### Agregado
- Manos libres: comandos de voz que empiezan con "Surco" ("Surco, siguiente", "Surco, pausa", "Surco, sube el volumen"...), tus listas con una palabra del nombre ("Surco, entrenar") y atajos propios. Un bip confirma cada comando y se apaga solo con la música en pausa. Reconoce sin internet con Vosk; el modelo de español se baja la primera vez y se puede borrar.
- Guía de manos libres con todos los comandos, tus listas y tus atajos.
- Servidor de descargas propio (opcional): si YouTube bloquea un video en el teléfono, Surco lo pide a tu servidor (carpeta `server/`, lista para Railway).

### Corregido
- "Pausar al desconectar audífonos" apagado ya no pausa igual.

## [1.3.3] - 2026-10-31

### Agregado
- Borrar canciones del teléfono desde el menú de cada canción o con el nuevo ⋮ del reproductor (donde ahora también está Compartir). Las que copiaste por cable piden además la confirmación de Android.

### Corregido
- Aleatorio sortea también la primera canción: antes empezaba siempre por la primera en orden alfabético.
- El menú de una canción ya no queda cortado por la barra de navegación, y no reabre el teclado al venir del buscador.

## [1.3.2] - 2026-10-29

### Corregido
- Descargar de YouTube ya no se queda en "Descargando… 0 %" para siempre: si YouTube bloquea el video (pide verificación anti-bots), Surco lo avisa a los 20 segundos.

## [1.3.1] - 2026-10-29

### Corregido
- El aviso de actualización muestra la barra de descarga siempre a la vista y las novedades como texto limpio, sin símbolos de Markdown.

## [1.3.0] - 2026-10-29

### Agregado
- Descargar de YouTube: pegando el link o con Compartir desde la app de YouTube. Elección de calidad, recorte con vista previa (sin recomprimir), título y artista limpios, portada cuadrada y letra de lrclib dentro del archivo. Se guarda en `Music/Surco`.
- Ecualizador con preajustes, ajuste por banda y volumen extra.
- Compartir la pista desde el reproductor y desde el menú de cada canción.
- Copia de seguridad de canciones y listas a una carpeta elegida; repetirla solo copia lo nuevo.
- Aviso de versiones nuevas con descarga e instalación desde la app.
- Halloween mucho más decorado: niebla, fantasmas, más telarañas, arañas y murciélagos, y calabazas con vela junto a la luna en la barra.

### Cambiado
- Surco ahora pide acceso a internet (solo para YouTube, letras y buscar actualizaciones) y permiso para instalar actualizaciones.

### Corregido
- Volver de compartir o del selector de carpetas ya no cambia la paleta en "Al abrir".

## [1.2.1] - 2026-10-19

### Cambiado
- En "Al abrir", durante una temporada, el tema festivo sale en la mitad de las aperturas (antes solo en la primera del día).

### Corregido
- Volver a Surco desde segundo plano ahora cuenta como una apertura: "Al abrir" cambia de paleta aunque Android no haya cerrado la app.
- Los botones de aleatorio y repetir cambian de color al tocarlos.
- Al cambiar de pestaña, cada lista vuelve a donde la dejaste en vez de saltar al inicio.

## [1.2.0] - 2026-10-19

### Agregado
- 8 paletas nuevas (14 en total): Arena, Menta, Cobre, Pizarra, Ciruela, Atardecer, Musgo y Cielo.
- Cambio de paleta automático: fija, cada día o cada vez que abres Surco (nunca la misma seguida).
- Celebraciones nuevas: Carnaval, San Patricio, Día de la Tierra, Día de la Madre, Día del Padre e Inti Raymi. Las fechas móviles se calculan por año.
- Decoraciones de temporada dibujadas en la app (telarañas, araña, murciélagos, calabazas, luces, nieve, papel picado, confeti, corazones, globos, tréboles, hojas, flores, sol). Se pueden apagar y quedan quietas si el teléfono reduce animaciones.
- En temporada, la primera apertura del día muestra su tema; las siguientes siguen el cambio automático.

### Cambiado
- Tocar una paleta mientras manda algo automático la aplica solo por hoy, sin apagar lo automático.
- Todos los textos con tildes y eñes.

### Corregido
- El aviso de cambio de paleta ya no se queda fijo en pantalla.
- El final de las listas y de Configuración ya no queda debajo de la barra de navegación de Android.
- Las muestras de paleta llenan el ancho en tres columnas.
- Carnaval y otras fechas móviles se calculaban un día corrido por el cambio de horario.

## [1.1.1] - 2026-10-19

### Corregido
- Elegir una paleta no tenía efecto durante una temporada (por ejemplo, Halloween).

## [1.1.0] - 2026-10-19

### Agregado
- Temas de temporada (Halloween, Día de Muertos, Navidad, Año Nuevo, San Valentín) y cumpleaños configurable.
- Tema del día aleatorio.

### Cambiado
- Una escucha cuenta con la regla de Last.fm: la mitad de la canción o 4 minutos.
- Caché de imágenes limitada a 24 MB.

### Corregido
- La biblioteca podía quedar vacía al escanear.
- Grabaciones de llamadas y notas de voz ya no se cuelan en la biblioteca.

## [1.0.0] - 2026-10-18

### Agregado
- Primera versión pública: biblioteca, letras sincronizadas, reproducción en segundo plano, cola, estadísticas locales, listas automáticas, seis temas y configuración.

[1.5.0]: https://github.com/Mickaell22/surco/releases/tag/v1.5.0
[1.4.1]: https://github.com/Mickaell22/surco/releases/tag/v1.4.1
[1.4.0]: https://github.com/Mickaell22/surco/releases/tag/v1.4.0
[1.3.3]: https://github.com/Mickaell22/surco/releases/tag/v1.3.3
[1.3.2]: https://github.com/Mickaell22/surco/releases/tag/v1.3.2
[1.3.1]: https://github.com/Mickaell22/surco/releases/tag/v1.3.1
[1.3.0]: https://github.com/Mickaell22/surco/releases/tag/v1.3.0
[1.2.1]: https://github.com/Mickaell22/surco/releases/tag/v1.2.1
[1.2.0]: https://github.com/Mickaell22/surco/releases/tag/v1.2.0
[1.1.1]: https://github.com/Mickaell22/surco/releases/tag/v1.1.1
[1.1.0]: https://github.com/Mickaell22/surco/releases/tag/v1.1.0
[1.0.0]: https://github.com/Mickaell22/surco/releases/tag/v1.0.0
