# Surco: contexto para Claude

Reproductor de música local para Android en Flutter. Repo **público** `github.com/Mickaell22/surco`, licencia MIT. El dueño es mickaell; las reglas generales (sin emojis, commits solo con permiso, nunca trailers de autoría, no hardcodear) viven en su CLAUDE.md global y mandan sobre todo.

## Prioridades del producto (lo que el dueño pidió explícitamente)

- **Ligera**: poca RAM, pocas dependencias, nada de fuentes descargadas. Antes de agregar un paquete, justificarlo.
- **Sobria**: paleta "ledger" (papel cálido, tinta, un acento) heredada de su Facturador. Nada chillón.
- **Mucha personalización** y cosas aleatorias/festivas (temas de temporada, decoraciones, cambio de paleta al abrir).
- **Métricas "en binario"**: quiere medir todo de su escucha (pendiente, ver abajo).
- Textos de la UI **en español con tildes y eñes** (hubo que corregirlos todos en la 1.2.0; no volver a escribir "cancion", "musica", "Configuracion").

## Flujo de trabajo

- **Conventional Commits** (`feat(tema):`, `fix(biblioteca):`, `chore(release):`, `docs:`...). Lo pidió explícito.
- **Commits chicos, uno por cambio lógico**, no todo de una sola vez. Cada commit debe compilar y pasar tests.
- Antes de cada commit: `flutter analyze` sin issues y `flutter test` en verde. Verificar que el mensaje no tenga `Co-Authored-By` ni similares.
- **Release** = subir `version` en `pubspec.yaml` y `appVersion` en `lib/ui/settings_page.dart`, actualizar `CHANGELOG.md`, `flutter build apk --release --split-per-abi`, probar en el teléfono, `gh release create vX.Y.Z` con los 3 APK y `SHA256SUMS.txt`.
- **Nombres de los APK del release sin versión** (`surco-arm64-v8a.apk`, `surco-armeabi-v7a.apk`, `surco-x86_64.apk`): el botón "Descargar APK" del README apunta a `releases/latest/download/surco-arm64-v8a.apk` y se rompe si el nombre lleva versión.
- Flutter está en `/opt/flutter/bin` y se corre como el usuario `mickaell` (Claude Code corre como root): `sudo -u mickaell -H bash -c 'export PATH=/opt/flutter/bin:$PATH; cd ...; flutter ...'`. Después de editar como root, `chown -R mickaell:mickaell .`.
- `gh` está logueado como `mickaell`; correrlo con `unset GH_TOKEN` (el GH_TOKEN de root es inválido).

## Probar en el teléfono

- TECNO POVA 5 (LH7n), Android 14, serial `103953736M000152`, por adb como `mickaell`.
- **Avisar antes de usar adb**: el dueño conecta el cable cuando se le pide. Si está usando el teléfono (la pantalla cambia sola), no tocar.
- `adb install -r` instala encima conservando datos (la firma ya es la de release). Nunca `adb uninstall` sin avisar: borra estadísticas y configuración.
- No capturar ni mostrar la pantalla de letras.
- En pantalla visible la app marca ~230 MB de PSS, pero ~130 MB son búferes de GPU de la pantalla (Graphics); en segundo plano baja a ~105 MB. No es una regresión. Medir con `dumpsys meminfo` mirando la línea `Graphics:`.

## Firma de release

- Llave en `~/.android-keys/` del usuario mickaell (`surco-release.jks` + `surco-key.properties`, permisos 600). `android/key.properties` es un symlink a ese archivo y está en `.gitignore`.
- Si se pierde la llave no se pueden publicar actualizaciones que se instalen encima. Nunca commitearla ni moverla al repo.

## Arquitectura (lib/)

- `main.dart`: singletons globales `settings`, `stats`, `library`, `player` (decisión consciente, ver comentario ponytail). Caché de imágenes limitada a 24 MB.
- `library.dart`: escaneo en isolate + caché JSON + portadas extraídas a disco. **El closure de `Isolate.run` va en una función de nivel superior** (`_runScan`): creado dentro de un método de `Library` arrastra `this` (no enviable) y el escaneo falla en silencio con la lista vacía. Pasó en la 1.1.0.
- Alcance por defecto: solo `Music` y `Download`; `_skipDirs` excluye WhatsApp, grabadoras (PhoneRecord, SoundRecorder...), tonos, notificaciones.
- `player.dart`: just_audio + just_audio_background (notificación, botones Bluetooth), audio_session (pausa al desconectar audífonos), sesión guardada para retomar. Mide tiempo realmente sonado con un Stopwatch.
- Pestañas de inicio: cada lista lleva `PageStorageKey` (TabBarView destruye la pestaña que no se ve y sin la llave volvía al inicio).
- Controles de reproducción: aleatorio y repetir no emiten en `playerStateStream`; `_Controls` escucha también `shuffleModeEnabledStream` y `loopModeStream`.
- `stats.dart`: historial local de escuchas. Regla de Last.fm: cuenta con la mitad de la pista o 4 minutos; pistas < 30 s nunca. Hoy solo guarda escuchas que cuentan.
- `settings.dart`: paletas (14 normales + temporadas), rotación (fija / cada día / al abrir; en "Al abrir" y en temporada, `seasonDraw` es una moneda por apertura que muestra el tema festivo la mitad de las veces; `newOpen()` cuenta como apertura volver desde segundo plano, lo llama el observer de ciclo de vida en `main.dart`), elección manual "solo por hoy", temporadas con fechas móviles (Pascua por Meeus/Jones/Butcher, n-ésimo domingo), cumpleaños configurable.
- `theme.dart`: `Ledger` (ThemeExtension) y `forPalette`. Papel es la paleta original a mano; las demás se derivan de un tono + acento.
- `ui/decor.dart`: decoraciones de temporada dibujadas con CustomPainter (formas propias, nada de imágenes ni personajes de terceros). Una sola animación lenta, `IgnorePointer`, quietas si el sistema reduce animaciones.
- `ui/brand.dart`: logo `SurcoMark` (disco con surcos), íconos y colores por lista. `tool/make_icon.py` genera el ícono del launcher con el mismo dibujo.

## Trampas conocidas

- **Fechas**: nunca sumar/restar días con `Duration` para lógica de calendario: cruza el cambio de horario y corre la fecha un día (pasó dos veces: en un test y en el cálculo de Carnaval). Usar `DateTime(y, m, d ± n)`.
- **Prioridad de paletas**: elección manual de hoy > cumpleaños > temporada (solo en la primera apertura del día, o siempre si la rotación es fija) > rotación > fija. Si se toca esto, actualizar `test/settings_test.dart`.
- **SnackBar con acción** se queda fijo por defecto en esta versión de Flutter: usar `persist: false`.
- **Borde a borde**: la app dibuja bajo la barra de navegación; toda lista larga necesita `MediaQuery.paddingOf(context).bottom` al final (el `MiniPlayer` reserva ese espacio cuando no suena nada).
- **Plugins fijados**: `permission_handler_android` 13.0.1 y `audio_session` 0.2.2 en `dependency_overrides`; las versiones nuevas exigen AGP 9 y Flutter 3.38 trae AGP 8.11.
- **No guardar datos personales en el código** (repo público): el cumpleaños del dueño se configura en la app, no va en el código.

## La música del dueño (fuera del repo)

- 294 canciones `.m4a` con portada, tags limpios y letra embebida, más 11 listas `.m3u` por ánimo, en `~/Desktop/Musica` y en el teléfono en `Music/Musica`.
- Script de descarga: `/root/ytm-tool/bajar.py` + `songs.tsv` (yt-dlp con YouTube Music, letras de lrclib, cookies de Firefox vía `YTM_COOKIES_BROWSER`). Re-ejecutable: salta lo ya bajado.
- **Música nueva (flujo preferido por el dueño)**: cuando diga "analiza de nuevo mi YouTube", hacerlo Claude completo (no quiere un comando suyo): leer el historial de Firefox (`~/.mozilla/firefox/nitiqjou.default-esr/places.sqlite`, copiarlo antes de abrirlo) desde la última vez, descartar lo ya bajado o que no es música, mostrar candidatas al dueño, bajar y clasificar en las listas por ánimo. Nunca más de 1 petición a la vez a YouTube (con 12 en paralelo bloqueó la IP como bot).

## Pendiente (pedido por el dueño)

- **PRIMERO al retomar: decoraciones de temporada mucho más cargadas** ("que alguien lo vea y diga waos, qué personalizado lo tienes"). Hoy Halloween es solo una telaraña, una araña y dos murciélagos y se siente vacío. Idea ya pensada para Halloween (`lib/ui/decor.dart`, `_DecorPainter`): viñeta morada suave en los bordes, luna tras los íconos de la barra, telarañas en 3-4 esquinas, 2 arañas colgando, 5 murciélagos de tamaños distintos, 2-3 fantasmas translúcidos que flotan, niebla que se mueve abajo, calabazas con brillo que titila en el hueco de la barra superior entre el logo y la lupa (solo en inicio: allí la barra termina en `anchorTop - 46`; en reproducción no hay hueco). Cuidar: nada encima de portadas, botón de play ni menús ⋮; en tema claro los fantasmas blancos no se ven (usar tinta con poca opacidad). Después subir igual el resto de temporadas (Navidad más nieve y acumulación, Muertos con pétalos de cempasúchil y velas, Año Nuevo con fuegos artificiales, etc.). Para revisar el diseño sin tocar el teléfono: un test que pinte `SeasonDecor` con override de paleta y `matchesGoldenFile`.

- **Métricas 1.3.0**: registrar también los saltos (hoy solo se guardan escuchas válidas), más saltadas, menos escuchadas, nunca escuchadas, por hora del día, racha de días, % que terminas, todo filtrable (rango, escuchas vs tiempo, cuántas mostrar), exportar el historial a JSON y **resumen semanal el domingo a las 20:00 con notificación** (requiere `flutter_local_notifications`; revisar compatibilidad con AGP 8.11).
- **Personalización**: tamaño de letra, forma de portadas, densidad de lista, acento a elección, estilo del reproductor.
- **Sincronizar la música** subida a algún lado para usarla en otros dispositivos (anotado para después, sin diseño todavía).
- README: el título (`docs/screenshots/title.svg`) tiene fondo **transparente** (una tarjeta clara se veía como un bloque blanco en GitHub oscuro) y colores que se leen sobre claro y oscuro: wordmark en el acento, subtítulo gris medio, disco con aro claro. No volver a `<picture>`. Verificar el primer cuadro con `rsvg-convert -b '#ffffff'` y `-b '#0d1117'` antes de publicar.
- Cuando estén las decoraciones nuevas, rehacer las capturas del README sumando una con un tema de temporada decorado (hoy son 2, de la 1.2.0: Listas y Configuración).
- Capturas del README: sin portadas de discos (repo público) ni barra de estado; recortar el mini reproductor.
