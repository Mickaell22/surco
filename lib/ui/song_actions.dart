import 'package:flutter/material.dart';

import '../library.dart';
import '../main.dart';
import '../theme.dart';
import 'home.dart';
import 'widgets.dart';

void showSongActions(BuildContext context, Song s) {
  final l = Ledger.of(context);
  void go(VoidCallback f) {
    Navigator.pop(context);
    f();
  }

  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Cover(s, size: 52, radius: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, maxLines: 2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: l.ink)),
                Text('${s.artist} · ${s.album}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: l.inkSoft)),
              ]),
            ),
          ]),
        ),
        const Divider(),
        _Action(Icons.playlist_play_rounded, 'Reproducir a continuacion', () => go(() => player.playNext(s))),
        _Action(Icons.playlist_add_rounded, 'Agregar a la cola', () => go(() => player.enqueue(s))),
        _Action(Icons.person_outline_rounded, 'Ir al artista', () => go(() {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPage(s.artist, library.byArtist[s.artist] ?? [s])));
            })),
        _Action(Icons.album_outlined, 'Ir al album', () => go(() {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPage(s.album, library.byAlbum[s.album] ?? [s])));
            })),
        const SizedBox(height: 8),
      ]),
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
