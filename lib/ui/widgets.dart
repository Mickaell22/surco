import 'dart:io';

import 'package:flutter/material.dart';

import '../library.dart';
import '../theme.dart';

/// Portada decodificada al tamano en pantalla (cacheWidth): una lista de 300
/// canciones no carga 300 imagenes de 600 px en RAM.
class Cover extends StatelessWidget {
  const Cover(this.song, {super.key, this.size = 48, this.radius = 8});
  final Song? song;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final path = song?.cover;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? ColoredBox(
                color: l.sunken,
                child: Icon(Icons.music_note_rounded, color: l.muted, size: size * .42),
              )
            : Image.file(
                File(path),
                cacheWidth: px,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => ColoredBox(color: l.sunken),
              ),
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, required this.onTap, this.playing = false, this.onMore, this.subtitle});
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool playing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(children: [
          Cover(song, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
                      color: playing ? l.accent : l.ink)),
              const SizedBox(height: 2),
              Text(subtitle ?? song.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: l.inkSoft)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(fmtDur(song.durationMs > 0 ? song.duration : null),
              style: TextStyle(fontSize: 12.5, color: l.muted, fontFeatures: tabular)),
          if (onMore != null)
            IconButton(
              tooltip: 'Opciones',
              onPressed: onMore,
              icon: Icon(Icons.more_vert_rounded, color: l.muted, size: 20),
            )
          else
            const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

/// Fila de grupo (artista, album o lista) con conteo.
class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.title, required this.songs, required this.onTap, this.icon});
  final String title;
  final List<Song> songs;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    final withCover = songs.firstWhere((s) => s.cover != null, orElse: () => songs.first);
    final total = songs.fold<int>(0, (a, s) => a + s.durationMs);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          icon == null
              ? Cover(withCover, size: 52, radius: 10)
              : Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: l.accentSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: l.accent),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: l.ink)),
              const SizedBox(height: 2),
              Text('${songs.length} ${songs.length == 1 ? 'cancion' : 'canciones'} · ${fmtDur(Duration(milliseconds: total))}',
                  style: TextStyle(fontSize: 13, color: l.muted, fontFeatures: tabular)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: l.muted),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title, body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: l.muted),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: l.ink)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.45, color: l.inkSoft)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}
