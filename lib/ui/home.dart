import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../library.dart';
import '../main.dart';
import '../theme.dart';
import 'now_playing.dart';
import 'song_actions.dart';
import 'widgets.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool? _granted;
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _askPermission();
  }

  Future<void> _askPermission() async {
    // Android 13+ usa READ_MEDIA_AUDIO; versiones previas, almacenamiento.
    final audio = await Permission.audio.request();
    final ok = audio.isGranted || (await Permission.storage.request()).isGranted;
    await Permission.notification.request();
    setState(() => _granted = ok);
    if (ok) library.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    if (_granted == false) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.folder_off_outlined,
          title: 'Surco necesita ver tu musica',
          body: 'Da permiso de acceso a archivos de audio para leer las canciones del telefono. Nada sale del dispositivo.',
          action: FilledButton(onPressed: openAppSettings, child: const Text('Abrir ajustes')),
        ),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: _searching
              ? TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(hintText: 'Buscar cancion, artista o album', isDense: true),
                )
              : const Text('Surco'),
          actions: [
            IconButton(
              tooltip: _searching ? 'Cerrar busqueda' : 'Buscar',
              icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () => setState(() {
                _searching = !_searching;
                _query = '';
              }),
            ),
            ListenableBuilder(
              listenable: library,
              builder: (_, _) => IconButton(
                tooltip: 'Volver a escanear',
                onPressed: library.scanning ? null : library.scan,
                icon: library.scanning
                    ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: l.muted))
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
          bottom: _searching
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: l.line,
                  indicatorColor: l.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: l.ink,
                  unselectedLabelColor: l.muted,
                  labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'Canciones'), Tab(text: 'Artistas'), Tab(text: 'Albumes'), Tab(text: 'Listas')],
                ),
        ),
        body: ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            if (library.songs.isEmpty) {
              return library.scanning || _granted == null
                  ? const Center(child: CircularProgressIndicator())
                  : EmptyState(
                      icon: Icons.library_music_outlined,
                      title: 'No hay musica todavia',
                      body: 'Copia tus canciones a la carpeta Music o Download del telefono y toca actualizar.',
                      action: OutlinedButton(onPressed: library.scan, child: const Text('Buscar de nuevo')),
                    );
            }
            if (_searching) return _SongList(_filter(library.songs));
            return TabBarView(children: [
              _SongList(library.songs, showShuffle: true),
              _Groups(library.byArtist),
              _Groups(library.byAlbum),
              _Playlists(),
            ]);
          },
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }

  List<Song> _filter(List<Song> all) => _query.isEmpty
      ? all
      : all
          .where((s) =>
              s.title.toLowerCase().contains(_query) ||
              s.artist.toLowerCase().contains(_query) ||
              s.album.toLowerCase().contains(_query))
          .toList();
}

class _SongList extends StatelessWidget {
  const _SongList(this.songs, {this.showShuffle = false});
  final List<Song> songs;
  final bool showShuffle;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const EmptyState(icon: Icons.search_off_rounded, title: 'Sin resultados', body: 'Prueba con otra palabra.');
    }
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final current = player.current?.path;
        return ListView.builder(
          // itemExtent fijo: el scroll no mide cada fila (mas fluido, menos trabajo).
          itemExtent: 64,
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: songs.length + (showShuffle ? 1 : 0),
          itemBuilder: (context, i) {
            if (showShuffle && i == 0) return ShuffleRow(songs);
            final s = songs[i - (showShuffle ? 1 : 0)];
            return SongTile(
              song: s,
              playing: s.path == current,
              onTap: () => player.playList(songs, songs.indexOf(s)),
              onMore: () => showSongActions(context, s),
            );
          },
        );
      },
    );
  }
}

class ShuffleRow extends StatelessWidget {
  const ShuffleRow(this.songs, {super.key});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return InkWell(
      onTap: () => player.playList(songs, 0, shuffle: true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: l.accentSoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.shuffle_rounded, color: l.accent),
          ),
          const SizedBox(width: 14),
          Text('Aleatorio', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: l.ink)),
          const Spacer(),
          Text('${songs.length} canciones', style: TextStyle(fontSize: 13, color: l.muted, fontFeatures: tabular)),
        ]),
      ),
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups(this.groups);
  final Map<String, List<Song>> groups;

  @override
  Widget build(BuildContext context) {
    final keys = groups.keys.toList();
    return ListView.builder(
      itemExtent: 68,
      itemCount: keys.length,
      itemBuilder: (context, i) => GroupTile(
        title: keys[i],
        songs: groups[keys[i]]!,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPage(keys[i], groups[keys[i]]!))),
      ),
    );
  }
}

class _Playlists extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (library.playlists.isEmpty) {
      return const EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'Sin listas',
        body: 'Surco lee archivos .m3u que esten junto a tu musica. Cada archivo aparece aqui como una lista.',
      );
    }
    return ListView.builder(
      itemExtent: 68,
      itemCount: library.playlists.length,
      itemBuilder: (context, i) {
        final p = library.playlists[i];
        return GroupTile(
          title: p.name,
          songs: p.songs,
          icon: Icons.queue_music_rounded,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPage(p.name, p.songs, keepOrder: true))),
        );
      },
    );
  }
}

class GroupPage extends StatelessWidget {
  const GroupPage(this.title, this.songs, {super.key, this.keepOrder = false});
  final String title;
  final List<Song> songs;
  final bool keepOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _SongList(songs, showShuffle: true),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final s = player.current;
        if (s == null) return const SizedBox.shrink();
        return Material(
          color: l.surfaceAlt,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => Navigator.push(context, NowPlaying.route()),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Progreso como hilo de 2 px: informa sin robar atencion.
                StreamBuilder<Duration>(
                  stream: player.audio.positionStream,
                  builder: (_, snap) {
                    final total = player.audio.duration?.inMilliseconds ?? 0;
                    final pos = snap.data?.inMilliseconds ?? 0;
                    return LinearProgressIndicator(
                      value: total == 0 ? 0 : (pos / total).clamp(0, 1),
                      minHeight: 2,
                      color: l.accent,
                      backgroundColor: l.line,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(children: [
                    Hero(tag: 'cover', child: Cover(s, size: 44)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: l.ink)),
                        Text(s.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: l.inkSoft)),
                      ]),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: player.audio.playerStateStream,
                      builder: (_, snap) {
                        final playing = snap.data?.playing ?? false;
                        return IconButton(
                          tooltip: playing ? 'Pausar' : 'Reproducir',
                          onPressed: player.toggle,
                          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: l.ink),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: player.next,
                      icon: Icon(Icons.skip_next_rounded, size: 28, color: l.ink),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
