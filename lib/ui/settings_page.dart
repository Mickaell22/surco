import 'package:flutter/material.dart';

import '../main.dart';
import '../native.dart';
import '../settings.dart';
import '../theme.dart';
import '../youtube.dart';
import 'brand.dart';
import 'equalizer_page.dart';
import 'update_dialog.dart';
import 'voice_guide_page.dart';

const appVersion = '1.4.0';
const repoUrl = 'github.com/Mickaell22/surco';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    // La app dibuja de borde a borde: el final de la lista no debe quedar
    // debajo de la barra de navegación de Android.
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: EdgeInsets.only(bottom: 32 + bottom),
          children: [
            const _Section('Apariencia'),
            if (_autoNotice() case final notice?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 18, color: l.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(notice, style: TextStyle(fontSize: 13, height: 1.4, color: l.inkSoft)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              // Tres columnas que llenan el ancho (un ancho fijo dejaba 2 y un hueco).
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = (c.maxWidth - 2 * 10) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in Palette.regular) _Swatch(p, width: w, selected: settings.activePalette == p),
                    ],
                  );
                },
              ),
            ),
            const _Label('Cambiar de paleta sola'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SegmentedButton<ThemeRotation>(
                showSelectedIcon: false,
                segments: [for (final r in ThemeRotation.values) ButtonSegment(value: r, label: Text(r.label))],
                selected: {settings.rotation},
                onSelectionChanged: (s) => settings.update(
                  (x) => x
                    ..rotation = s.first
                    ..overridePalette = null
                    ..overrideDay = null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(switch (settings.rotation) {
                ThemeRotation.fixed => 'Siempre la paleta que elijas.',
                ThemeRotation.daily => 'Una paleta al azar cada día; hoy tocó ${dailyPalette(DateTime.now()).label}.',
                ThemeRotation.launch => 'Una paleta al azar cada vez que abres Surco, nunca la misma seguida.',
              }, style: TextStyle(fontSize: 13, color: l.inkSoft)),
            ),
            _Toggle(
              'Temas de temporada',
              _seasonHint(),
              settings.seasonalThemes,
              (v) => settings.update((x) => x.seasonalThemes = v),
            ),
            if (settings.seasonalThemes)
              _Toggle(
                'Decoraciones de temporada',
                'Arañas, luces, papel picado, confeti... quedan quietas si tu teléfono reduce animaciones',
                settings.decorations,
                (v) => settings.update((x) => x.decorations = v),
              ),
            ListTile(
              leading: Icon(Icons.cake_outlined, color: l.inkSoft),
              title: Text('Tu cumpleaños', style: TextStyle(color: l.ink)),
              subtitle: Text(
                settings.birthdayMonth == null
                    ? 'Ese día Surco se pone de fiesta'
                    : '${settings.birthdayDay} de ${_months[settings.birthdayMonth! - 1]}',
                style: TextStyle(color: l.inkSoft),
              ),
              trailing: settings.birthdayMonth == null
                  ? null
                  : IconButton(
                      tooltip: 'Quitar cumpleaños',
                      icon: Icon(Icons.close_rounded, color: l.muted),
                      onPressed: () => settings.update(
                        (x) => x
                          ..birthdayMonth = null
                          ..birthdayDay = null,
                      ),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  helpText: 'Elige tu cumpleaños (el año no importa)',
                  firstDate: DateTime(now.year),
                  lastDate: DateTime(now.year, 12, 31),
                  initialDate: settings.birthdayMonth == null
                      ? now
                      : DateTime(now.year, settings.birthdayMonth!, settings.birthdayDay!),
                );
                if (d != null) {
                  settings.update(
                    (x) => x
                      ..birthdayMonth = d.month
                      ..birthdayDay = d.day,
                  );
                }
              },
            ),
            const _Label('Modo'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) => settings.update((x) => x.mode = s.first),
              ),
            ),
            _Toggle(
              'Negro puro en modo oscuro',
              'Ahorra batería en pantallas AMOLED',
              settings.pureBlack,
              (v) => settings.update((x) => x.pureBlack = v),
            ),
            const _Section('Reproducción'),
            ListTile(
              leading: const Icon(Icons.mic_none_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceGuidePage())),
              title: const Text('Manos libres'),
              subtitle: Text(
                'Comandos, atajos y voz descargada. Se apaga solo tras '
                '${settings.voiceIdleMinutes} min con la música en pausa.',
              ),
              trailing: DropdownButton<int>(
                value: settings.voiceIdleMinutes,
                underline: const SizedBox.shrink(),
                items: [
                  for (final m in const [1, 3, 5, 10, 20]) DropdownMenuItem(value: m, child: Text('$m min')),
                ],
                onChanged: (m) => settings.update((x) => x.voiceIdleMinutes = m!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const Text('Ecualizador'),
              subtitle: Text(settings.eqEnabled ? settings.eqPreset.label : 'Apagado'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EqualizerPage())),
            ),
            _Toggle(
              'Pausar al desconectar audífonos',
              'Cable o Bluetooth: la música no sale por el parlante',
              settings.pauseOnUnplug,
              (v) => settings.update((x) => x.pauseOnUnplug = v),
            ),
            _Toggle(
              'Retomar donde lo dejé',
              'Al abrir la app vuelven la última cola y la posición',
              settings.resumeSession,
              (v) => settings.update((x) => x.resumeSession = v),
            ),
            _Toggle(
              'Saltar silencios',
              'Recorta los silencios largos al inicio y al final',
              settings.skipSilence,
              (v) => settings.update((x) => x.skipSilence = v),
            ),
            const _Section('Biblioteca'),
            RadioGroup<LibraryScope>(
              groupValue: settings.scope,
              onChanged: (v) {
                settings.update((x) => x.scope = v!);
                library.scan();
              },
              child: Column(
                children: [
                  for (final s in LibraryScope.values)
                    RadioListTile<LibraryScope>(
                      value: s,
                      activeColor: l.accent,
                      title: Text(s.label, style: TextStyle(color: l.ink)),
                      subtitle: Text(s.hint, style: TextStyle(color: l.inkSoft)),
                    ),
                ],
              ),
            ),
            _Toggle(
              'Ignorar audios de menos de 30 s',
              'Deja fuera notas de voz, tonos y efectos',
              settings.ignoreShort,
              (v) {
                settings.update((x) => x.ignoreShort = v);
                library.scan();
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh_rounded, color: l.inkSoft),
              title: Text('Volver a escanear ahora', style: TextStyle(color: l.ink)),
              onTap: library.scan,
            ),
            ListTile(
              leading: Icon(Icons.dns_outlined, color: l.inkSoft),
              title: Text('Servidor de descargas', style: TextStyle(color: l.ink)),
              subtitle: Text(
                settings.downloadServer == null
                    ? 'Opcional: baja los videos que YouTube bloquea en el teléfono'
                    : 'Configurado: se usa si YouTube bloquea un video',
                style: TextStyle(color: l.inkSoft),
              ),
              onTap: () => _serverDialog(context),
            ),
            ListTile(
              leading: Icon(Icons.save_alt_rounded, color: l.inkSoft),
              title: Text('Copia de seguridad', style: TextStyle(color: l.ink)),
              subtitle: Text(
                'Copia canciones y listas a la carpeta que elijas (SD, USB, Drive). Repetirla solo copia lo nuevo.',
                style: TextStyle(color: l.inkSoft),
              ),
              onTap: () => _backup(context),
            ),
            const _Section('Estadísticas'),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: l.inkSoft),
              title: Text('Borrar historial de escuchas', style: TextStyle(color: l.ink)),
              subtitle: Text(
                '${stats.events.length} escuchas guardadas en este teléfono',
                style: TextStyle(color: l.inkSoft),
              ),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Borrar historial'),
                    content: const Text('Se pierden las estadísticas y las listas automáticas. No se puede deshacer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Borrar')),
                    ],
                  ),
                );
                if (ok == true) await stats.clear();
              },
            ),
            const _Section('Acerca de'),
            _Toggle(
              'Avisar de versiones nuevas',
              'Una vez al día revisa GitHub al abrir la app',
              settings.checkUpdates,
              (v) => settings.update((x) => x.checkUpdates = v),
            ),
            ListTile(
              leading: Icon(Icons.system_update_rounded, color: l.inkSoft),
              title: Text('Buscar actualizaciones', style: TextStyle(color: l.ink)),
              onTap: () => checkForUpdate(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  const SurcoMark(size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Surco $appVersion',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: l.ink),
                        ),
                        const SizedBox(height: 2),
                        Text('Tu música, sin cuentas ni anuncios.', style: TextStyle(fontSize: 13, color: l.inkSoft)),
                        Text(repoUrl, style: TextStyle(fontSize: 13, color: l.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Explica qué tema está mandando cuando no es la paleta elegida.
String? _autoNotice() {
  final active = settings.activePalette;
  if (settings.hasOverrideToday) {
    return 'Hoy usas ${active.label} porque la elegiste. Mañana vuelve lo automático.';
  }
  if (settings.autoPaletteFor(DateTime.now()) == null) return null;
  final why = active.seasonal ? 'temporada' : 'cambio automático';
  return 'Ahora manda ${active.label} ($why). Toca una paleta para usarla hoy.';
}

String _seasonHint() {
  final now = DateTime.now();
  if (settings.isBirthday(now)) return 'Hoy es tu cumpleaños: modo fiesta';
  final s = seasonFor(now);
  return s == null ? 'Halloween, Navidad, Carnaval y más se aplican solos en sus fechas' : 'Ahora mismo: ${s.label}';
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Ledger.of(context).accent),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Ledger.of(context).ink),
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.title, this.subtitle, this.value, this.onChanged);
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: l.bg,
      activeTrackColor: l.accent,
      title: Text(title, style: TextStyle(color: l.ink)),
      subtitle: Text(subtitle, style: TextStyle(color: l.inkSoft)),
    );
  }
}

/// Muestra de paleta: fondo, tinta y acento reales del tema en el brillo actual.
class _Swatch extends StatelessWidget {
  const _Swatch(this.p, {required this.selected, required this.width});
  final Palette p;
  final bool selected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cur = Ledger.of(context);
    final t = Ledger.forPalette(p, Theme.of(context).brightness, pureBlack: settings.pureBlack);
    return Semantics(
      selected: selected,
      button: true,
      label: 'Paleta ${p.label}',
      child: InkWell(
        onTap: () {
          final justToday = settings.choosePalette(p);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                // Con acción, Flutter deja el aviso fijo por defecto: se fuerza a irse solo.
                persist: false,
                duration: const Duration(seconds: 4),
                content: Text(
                  justToday
                      ? 'Hoy usas ${p.label}. Mañana vuelve el cambio automático.'
                      : 'Paleta ${p.label} aplicada.',
                ),
                action: justToday ? SnackBarAction(label: 'Deshacer', onPressed: settings.clearOverride) : null,
              ),
            );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? cur.accent : cur.line, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 9, backgroundColor: t.accent),
                  const SizedBox(width: 6),
                  CircleAvatar(radius: 9, backgroundColor: t.ink),
                  const Spacer(),
                  if (selected) Icon(Icons.check_rounded, size: 16, color: t.accent),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
              ),
              Text(
                p.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: t.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _backup(BuildContext context) async {
  final tree = await pickFolder();
  if (tree == null || !context.mounted) return;
  final files = [for (final s in library.songs) s.path, for (final p in library.playlists) ?p.path];
  final progress = ValueNotifier((0, files.length));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Copiando música'),
        content: ValueListenableBuilder(
          valueListenable: progress,
          builder: (_, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: p.$2 == 0 ? null : p.$1 / p.$2),
              const SizedBox(height: 12),
              Text('${p.$1} de ${p.$2} archivos'),
            ],
          ),
        ),
      ),
    ),
  );
  String message;
  try {
    final r = await backup(tree, files, (done, total) => progress.value = (done, total));
    message = 'Copiadas ${r.copied}, ya estaban ${r.skipped}${r.failed > 0 ? ', fallaron ${r.failed}' : ''}.';
  } catch (e) {
    message = 'No se pudo copiar: $e';
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), persist: false));
}

/// Dirección y clave del servidor de descargas propio, con botón para probarlo.
Future<void> _serverDialog(BuildContext context) async {
  final url = TextEditingController(text: settings.serverUrl);
  final token = TextEditingController(text: settings.serverToken);
  String? status;
  var testing = false;
  await showDialog<void>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => AlertDialog(
        title: const Text('Servidor de descargas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu propia API (carpeta server/ del repo de Surco). Surco la usa solo cuando YouTube '
                'no le entrega el audio al teléfono.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Dirección', hintText: 'https://…'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: token,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Clave'),
              ),
              if (status != null) ...[const SizedBox(height: 12), Text(status!)],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: testing
                ? null
                : () async {
                    setState(() => (testing, status) = (true, 'Probando…'));
                    final problem = await checkServer((url: url.text.trim(), token: token.text.trim()));
                    setState(() => (testing, status) = (false, problem ?? 'Funciona.'));
                  },
            child: const Text('Probar'),
          ),
          TextButton(
            onPressed: () {
              settings.update((x) {
                x.serverUrl = url.text.trim();
                x.serverToken = token.text.trim();
              });
              Navigator.pop(d);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
