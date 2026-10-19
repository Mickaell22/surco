import 'package:flutter/material.dart';

import '../main.dart';
import '../settings.dart';
import '../theme.dart';
import 'brand.dart';

const appVersion = '1.1.1';
const repoUrl = 'github.com/Mickaell22/surco';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const _Section('Apariencia'),
          if (settings.activePalette != settings.palette || settings.dailyTheme)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: l.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ahora manda ${settings.activePalette.label}${settings.activePalette.seasonal ? ' (temporada)' : ' (tema del dia)'}. Toca una paleta para usarla siempre.',
                    style: TextStyle(fontSize: 13, color: l.inkSoft),
                  ),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final p in Palette.regular) _Swatch(p, selected: settings.palette == p && !settings.dailyTheme),
            ]),
          ),
          _Toggle(
            'Tema del dia',
            settings.dailyTheme
                ? 'Hoy toco ${dailyPalette(DateTime.now()).label}. Manana sale otra al azar'
                : 'Cada dia una paleta al azar',
            settings.dailyTheme,
            (v) => settings.update((x) => x.dailyTheme = v),
          ),
          _Toggle(
            'Temas de temporada',
            _seasonHint(),
            settings.seasonalThemes,
            (v) => settings.update((x) => x.seasonalThemes = v),
          ),
          ListTile(
            leading: Icon(Icons.cake_outlined, color: l.inkSoft),
            title: Text('Tu cumpleanos', style: TextStyle(color: l.ink)),
            subtitle: Text(
              settings.birthdayMonth == null
                  ? 'Ese dia Surco se pone de fiesta'
                  : '${settings.birthdayDay} de ${_months[settings.birthdayMonth! - 1]}',
              style: TextStyle(color: l.inkSoft),
            ),
            trailing: settings.birthdayMonth == null
                ? null
                : IconButton(
                    tooltip: 'Quitar cumpleanos',
                    icon: Icon(Icons.close_rounded, color: l.muted),
                    onPressed: () => settings.update((x) => x
                      ..birthdayMonth = null
                      ..birthdayDay = null),
                  ),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                helpText: 'Elige tu cumpleanos (el ano no importa)',
                firstDate: DateTime(now.year),
                lastDate: DateTime(now.year, 12, 31),
                initialDate: settings.birthdayMonth == null
                    ? now
                    : DateTime(now.year, settings.birthdayMonth!, settings.birthdayDay!),
              );
              if (d != null) {
                settings.update((x) => x
                  ..birthdayMonth = d.month
                  ..birthdayDay = d.day);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
            'Ahorra bateria en pantallas AMOLED',
            settings.pureBlack,
            (v) => settings.update((x) => x.pureBlack = v),
          ),
          const _Section('Reproduccion'),
          _Toggle(
            'Pausar al desconectar audifonos',
            'Cable o Bluetooth: la musica no sale por el parlante',
            settings.pauseOnUnplug,
            (v) => settings.update((x) => x.pauseOnUnplug = v),
          ),
          _Toggle(
            'Retomar donde lo deje',
            'Al abrir la app vuelve la ultima cola y posicion',
            settings.resumeSession,
            (v) => settings.update((x) => x.resumeSession = v),
          ),
          _Toggle(
            'Saltar silencios',
            'Recorta los silencios largos al inicio y final',
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
            child: Column(children: [
              for (final s in LibraryScope.values)
                RadioListTile<LibraryScope>(
                  value: s,
                  activeColor: l.accent,
                  title: Text(s.label, style: TextStyle(color: l.ink)),
                  subtitle: Text(s.hint, style: TextStyle(color: l.inkSoft)),
                ),
            ]),
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
          const _Section('Estadisticas'),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: l.inkSoft),
            title: Text('Borrar historial de escuchas', style: TextStyle(color: l.ink)),
            subtitle: Text('${stats.events.length} escuchas guardadas en este telefono', style: TextStyle(color: l.inkSoft)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Borrar historial'),
                  content: const Text('Se pierden las estadisticas y las listas automaticas. No se puede deshacer.'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              const SurcoMark(size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Surco $appVersion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: l.ink)),
                  Text('Tu musica, sin cuentas ni anuncios. $repoUrl', style: TextStyle(fontSize: 13, color: l.inkSoft)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

const _months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
    'septiembre', 'octubre', 'noviembre', 'diciembre'];

String _seasonHint() {
  final now = DateTime.now();
  if (settings.seasonalThemes && settings.isBirthday(now)) return 'Hoy es tu cumpleanos: modo fiesta';
  final s = seasonFor(now);
  return s == null
      ? 'Halloween, Dia de Muertos, Navidad, Ano Nuevo y San Valentin se aplican solos'
      : 'Ahora mismo: ${s.label}';
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Ledger.of(context).accent)),
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
  const _Swatch(this.p, {required this.selected});
  final Palette p;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cur = Ledger.of(context);
    final t = Ledger.forPalette(p, Theme.of(context).brightness, pureBlack: settings.pureBlack);
    return Semantics(
      selected: selected,
      button: true,
      label: 'Tema ${p.label}',
      child: InkWell(
        onTap: () {
          // Elegir una paleta es decir "quiero esta": apaga lo automatico para
          // que no parezca que el toque no hizo nada.
          final overridden = settings.activePalette != settings.palette || settings.dailyTheme;
          settings.update((x) => x
            ..palette = p
            ..dailyTheme = false
            ..seasonalThemes = false);
          if (overridden) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('Usando ${p.label}. Tema del dia y de temporada desactivados.'),
                action: SnackBarAction(
                  label: 'Deshacer',
                  onPressed: () => settings.update((x) => x.seasonalThemes = true),
                ),
              ));
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? cur.accent : cur.line, width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 9, backgroundColor: t.accent),
              const SizedBox(width: 6),
              CircleAvatar(radius: 9, backgroundColor: t.ink),
              const Spacer(),
              if (selected) Icon(Icons.check_rounded, size: 16, color: t.accent),
            ]),
            const SizedBox(height: 10),
            Text(p.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
            Text(p.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: t.inkSoft)),
          ]),
        ),
      ),
    );
  }
}
