import 'package:flutter/material.dart';

import '../main.dart';
import '../native.dart';
import '../theme.dart';
import '../voice.dart';

/// Guía de manos libres: cómo usarlo, todos los comandos, los comandos que
/// salen de tus listas, tus atajos y el modelo de voz descargado.
class VoiceGuidePage extends StatefulWidget {
  const VoiceGuidePage({super.key});

  @override
  State<VoiceGuidePage> createState() => _VoiceGuidePageState();
}

class _VoiceGuidePageState extends State<VoiceGuidePage> {
  bool? _modelReady;

  @override
  void initState() {
    super.initState();
    voiceModelReady().then((r) => mounted ? setState(() => _modelReady = r) : null);
  }

  static const _commands = [
    ('Siguiente canción', 'Surco, siguiente · pasa · salta'),
    ('Anterior', 'Surco, anterior · atrás · la de antes'),
    ('Pausar', 'Surco, pausa · para · detente · silencio'),
    ('Reanudar', 'Surco, sigue · dale · continúa · play'),
    ('Volumen', 'Surco, sube el volumen · baja el volumen · más fuerte · más bajo'),
    ('Aleatorio de todo', 'Surco, aleatorio · mezcla'),
    ('Repetir esta canción', 'Surco, repite · otra vez'),
    ('Poner algo', 'Surco, pon + lista o artista'),
    ('Apagar manos libres', 'Surco, apágate · desactiva'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    TextStyle h(double size) => TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: l.ink);
    final body = TextStyle(fontSize: 14, height: 1.45, color: l.inkSoft);
    return Scaffold(
      appBar: AppBar(title: const Text('Manos libres')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text('Cómo se usa', style: h(17)),
            const SizedBox(height: 6),
            Text(
              '1. En el reproductor toca el micrófono. Queda una notificación "Surco te escucha".\n'
              '2. Di "Surco" y el comando, de corrido: "Surco, siguiente". Suena un bip si lo entendió '
              'y un tono grave si no.\n'
              '3. También puedes decir solo "Surco", esperar el bip y en 6 segundos decir el comando.\n'
              '4. Se apaga solo si la música lleva ${settings.voiceIdleMinutes} min en pausa '
              '(por ejemplo al guardar los audífonos), o con "Surco, apágate".',
              style: body,
            ),
            const SizedBox(height: 20),
            Text('Comandos', style: h(17)),
            const SizedBox(height: 4),
            for (final (what, say) in _commands)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      what,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: l.ink),
                    ),
                    Text('«$say»', style: body),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text('Tus listas', style: h(17)),
            Text('Basta con una palabra del nombre, sin "pon".', style: body),
            const SizedBox(height: 4),
            for (final p in library.playlists)
              if (keywords(p.name).firstOrNull case final k?)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name, style: TextStyle(color: l.ink)),
                  subtitle: Text('«Surco, $k»', style: body),
                ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Tus atajos', style: h(17))),
                TextButton.icon(
                  onPressed: () => _addShortcut(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            Text(
              'Una frase tuya que pone una lista o un artista, como «Surco, modo moto». '
              'Usa palabras comunes en español: nombres inventados o en otro idioma pueden no reconocerse.',
              style: body,
            ),
            for (final e in settings.voiceShortcuts.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('«Surco, ${e.key}»', style: TextStyle(color: l.ink)),
                subtitle: Text(e.value.replaceFirst(':', ': '), style: body),
                trailing: IconButton(
                  tooltip: 'Borrar atajo',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => settings.update((s) => s.voiceShortcuts = {...s.voiceShortcuts}..remove(e.key)),
                ),
              ),
            const SizedBox(height: 20),
            Text('Voz en español', style: h(17)),
            const SizedBox(height: 4),
            Text(switch (_modelReady) {
              null => 'Revisando…',
              true =>
                'Descargada (unos 40 MB). Entiende sin internet. Si no usas manos libres puedes borrarla; '
                    'se vuelve a bajar al prender el micrófono.',
              false => 'No descargada. Se baja (unos 40 MB) la primera vez que prendes el micrófono.',
            }, style: body),
            if (_modelReady == true)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await voice.stop();
                    await deleteVoiceModel();
                    if (mounted) setState(() => _modelReady = false);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Borrar voz descargada'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addShortcut(BuildContext context) async {
    final phrase = TextEditingController();
    final targets = [
      for (final p in library.playlists) ('lista:${p.name}', 'Lista · ${p.name}'),
      for (final a in library.byArtist.keys) ('artista:$a', 'Artista · $a'),
    ];
    if (targets.isEmpty) return;
    var target = targets.first.$1;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: const Text('Nuevo atajo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phrase,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Después de «Surco», di…', hintText: 'modo moto'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: target,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pone'),
                items: [
                  for (final (v, label) in targets)
                    DropdownMenuItem(
                      value: v,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => target = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final p = fold(phrase.text);
                if (p.isEmpty) return;
                settings.update((s) => s.voiceShortcuts = {...s.voiceShortcuts, p: target});
                Navigator.pop(d);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (voice.active && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(persist: false, content: Text('Apaga y prende el micrófono para que reconozca el atajo nuevo.')),
      );
    }
  }
}
