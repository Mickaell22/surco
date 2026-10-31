import 'package:flutter/material.dart';

import '../library.dart';
import '../main.dart';
import '../native.dart';
import '../theme.dart';
import 'home.dart';
import 'widgets.dart';

void showSongActions(BuildContext context, Song s) {
  // Si venía del buscador, que el teclado no vuelva a abrirse al cerrar el menú.
  FocusManager.instance.primaryFocus?.unfocus();
  final l = Ledger.of(context);
  void go(VoidCallback f) {
    Navigator.pop(context);
    f();
  }

  showModalBottomSheet<void>(
    context: context,
    // Con siete acciones el menú pasa la altura por defecto (9/16 de pantalla)
    // y la última quedaba tapada por la barra de navegación.
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Cover(s, size: 52, radius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 2,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: l.ink),
                      ),
                      Text(
                        '${s.artist} · ${s.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: l.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _Action(Icons.playlist_play_rounded, 'Reproducir a continuación', () => go(() => player.playNext(s))),
          _Action(Icons.playlist_add_rounded, 'Agregar a la cola', () => go(() => player.enqueue(s))),
          _Action(
            Icons.person_outline_rounded,
            'Ir al artista',
            () => go(() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupPage(s.artist, library.byArtist[s.artist] ?? [s])),
              );
            }),
          ),
          _Action(
            Icons.album_outlined,
            'Ir al álbum',
            () => go(() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupPage(s.album, library.byAlbum[s.album] ?? [s])),
              );
            }),
          ),
          _Action(Icons.share_outlined, 'Compartir', () => go(() => shareSong(s))),
          _Action(Icons.delete_outline_rounded, 'Borrar del teléfono', () => go(() => confirmDelete(context, s))),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return ListTile(
      leading: Icon(icon, color: l.inkSoft),
      title: Text(label, style: TextStyle(fontSize: 15, color: l.ink)),
      onTap: onTap,
    );
  }
}

/// Pide confirmación, borra el archivo y lo saca de la cola y la biblioteca.
Future<void> confirmDelete(BuildContext context, Song s) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Borrar canción'),
      content: Text('Se borra "${s.title}" de ${s.artist} del teléfono. No se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final deleted = await deleteSongFile(s.path);
  if (deleted) {
    await player.forget(s.path);
    await library.scan();
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(persist: false, content: Text(deleted ? 'Se borró "${s.title}".' : 'No se borró "${s.title}".')),
  );
}
