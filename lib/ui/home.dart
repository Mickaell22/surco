import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../library.dart';
import '../main.dart';
import '../settings.dart';
import '../smart.dart';
import '../theme.dart';
import 'brand.dart';
import 'decor.dart';
import 'now_playing.dart';
import 'settings_page.dart';
import 'song_actions.dart';
import 'stats_page.dart';
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
    if (ok) library.load(onReady: () => player.restoreSession(library.byPath));
  }

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    if (_granted == false) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.folder_off_outlined,
          title: 'Surco necesita ver tu música',
          body:
              'Da permiso de acceso a archivos de audio para leer las canciones del teléfono. Nada sale del dispositivo.',
          action: FilledButton(onPressed: openAppSettings, child: const Text('Abrir ajustes')),
        ),
      );
    }
    // Las decoraciones cuelgan del borde inferior de las pestanas.
    final decorTop = MediaQuery.paddingOf(context).top + kToolbarHeight + (_searching ? 0 : 46);
    return Stack(
      children: [
        DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: _searching
                  ? TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      decoration: const InputDecoration(hintText: 'Buscar canción, artista o álbum', isDense: true),
                    )
                  : const Wordmark(),
              actions: [
                IconButton(
                  tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
                  icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    _query = '';
                  }),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) => switch (v) {
                    'stats' => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsPage())),
                    'settings' => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                    _ => library.scan(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'stats',
                      child: ListTile(leading: Icon(Icons.insights_outlined), title: Text('Estadísticas')),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: ListTile(leading: Icon(Icons.tune_rounded), title: Text('Configuración')),
                    ),
                    PopupMenuItem(
                      value: 'scan',
                      child: ListTile(leading: Icon(Icons.refresh_rounded), title: Text('Volver a escanear')),
                    ),
                  ],
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
                      tabs: const [
                        Tab(text: 'Canciones'),
                        Tab(text: 'Artistas'),
                        Tab(text: 'Álbumes'),
                        Tab(text: 'Listas'),
                      ],
                    ),
            ),
            body: ListenableBuilder(
              listenable: Listenable.merge([library, stats, settings]),
              builder: (context, _) {
                if (library.songs.isEmpty) {
                  return library.scanning || _granted == null
                      ? const Center(child: CircularProgressIndicator())
                      : EmptyState(
                          icon: Icons.library_music_outlined,
                          title: 'No hay música todavía',
                          body: library.error != null
                              ? 'No se pudo leer la música: ${library.error}'
                              : 'Copia tus canciones a la carpeta Music o Download del teléfono y toca actualizar.',
                          action: OutlinedButton(onPressed: library.scan, child: const Text('Buscar de nuevo')),
                        );
                }
                final body = _searching
                    ? _SongList(_filter(library.songs))
                    : TabBarView(
                        children: [
                          _SongList(
                            sortSongs(library.songs, settings.sort, stats.playCounts()),
                            showShuffle: true,
                            showSort: true,
                          ),
                          _Groups(library.byArtist),
                          _Groups(library.byAlbum),
                          _Playlists(),
                        ],
                      );
                return Column(
                  children: [
                    if (library.scanning)
                      LinearProgressIndicator(minHeight: 2, color: l.accent, backgroundColor: l.line),
                    if (settings.seasonalThemes && settings.isBirthday(DateTime.now()))
                      Container(
                        width: double.infinity,
                        color: l.accentSoft,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.cake_outlined, color: l.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Feliz cumpleaños. Hoy suena lo que tú quieras.',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: l.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(child: body),
                  ],
                );
              },
            ),
            bottomNavigationBar: const MiniPlayer(),
          ),
        ),
        Positioned.fill(
          child: ListenableBuilder(
            listenable: settings,
            builder: (_, _) => SeasonDecor(anchorTop: decorTop),
          ),
        ),
      ],
    );
  }

  List<Song> _filter(List<Song> all) => _query.isEmpty
      ? all
      : all
            .where(
              (s) =>
                  s.title.toLowerCase().contains(_query) ||
                  s.artist.toLowerCase().contains(_query) ||
                  s.album.toLowerCase().contains(_query),
            )
            .toList();
}

class _SongList extends StatelessWidget {
  const _SongList(this.songs, {this.showShuffle = false, this.showSort = false});
  final List<Song> songs;
  final bool showShuffle, showSort;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        body: 'Prueba con otra palabra.',
      );
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
            if (showShuffle && i == 0) return ShuffleRow(songs, showSort: showSort);
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
  const ShuffleRow(this.songs, {super.key, this.showSort = false});
  final List<Song> songs;
  final bool showSort;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return InkWell(
      onTap: () => player.playList(songs, 0, shuffle: true),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: l.accentSoft, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.shuffle_rounded, color: l.accent),
            ),
            const SizedBox(width: 14),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aleatorio',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: l.ink),
                ),
                Text(
                  '${songs.length} canciones',
                  style: TextStyle(fontSize: 13, color: l.muted, fontFeatures: tabular),
                ),
              ],
            ),
            const Spacer(),
            if (showSort)
              PopupMenuButton<SongSort>(
                tooltip: 'Ordenar',
                initialValue: settings.sort,
                onSelected: (v) => settings.update((x) => x.sort = v),
                itemBuilder: (_) => [for (final o in SongSort.values) PopupMenuItem(value: o, child: Text(o.label))],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 18, color: l.inkSoft),
                      const SizedBox(width: 6),
                      Text(settings.sort.label, style: TextStyle(fontSize: 13.5, color: l.inkSoft)),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
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
    final l = Ledger.of(context);
    final auto = smartPlaylists(library, stats);
    final mine = library.playlists;
    Widget row(Playlist p, {bool keepOrder = true}) => GroupTile(
      title: p.name,
      songs: p.songs,
      art: PlaylistArt(name: p.name, songs: p.songs),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPage(p.name, p.songs, playlist: true))),
    );
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        t.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: l.muted),
      ),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        header('Hechas para ti'),
        for (final p in auto) SizedBox(height: 68, child: row(p)),
        header('Tus listas'),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Surco lee archivos .m3u que estén junto a tu música. Cada archivo aparece aquí como una lista.',
              style: TextStyle(fontSize: 14, height: 1.45, color: l.inkSoft),
            ),
          ),
        for (final p in mine) SizedBox(height: 68, child: row(p)),
      ],
    );
  }
}

class GroupPage extends StatelessWidget {
  const GroupPage(this.title, this.songs, {super.key, this.playlist = false});
  final String title;
  final List<Song> songs;
  final bool playlist;

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    final total = songs.fold<int>(0, (a, s) => a + s.durationMs);
    final withCover = songs.where((s) => s.cover != null).firstOrNull ?? songs.firstOrNull;
    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    playlist
                        ? PlaylistArt(name: title, songs: songs, size: 112)
                        : Cover(withCover, size: 112, radius: 14),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                              color: l.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${songs.length} canciones · ${fmtDur(Duration(milliseconds: total))}',
                            style: TextStyle(fontSize: 13.5, color: l.inkSoft, fontFeatures: tabular),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: songs.isEmpty ? null : () => player.playList(songs, 0),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Reproducir'),
                                style: FilledButton.styleFrom(backgroundColor: l.ink, foregroundColor: l.bg),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Aleatorio',
                                onPressed: songs.isEmpty ? null : () => player.playList(songs, 0, shuffle: true),
                                icon: Icon(Icons.shuffle_rounded, color: l.ink),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverFixedExtentList(
              itemExtent: 64,
              delegate: SliverChildBuilderDelegate(
                childCount: songs.length,
                (context, i) => SongTile(
                  song: songs[i],
                  playing: songs[i].path == player.current?.path,
                  onTap: () => player.playList(songs, i),
                  onMore: () => showSongActions(context, songs[i]),
                ),
              ),
            ),
          ],
        ),
      ),
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
        // Sin cancion igual reserva la barra de navegacion de Android (la app es
        // de borde a borde): si no, el final de las listas queda tapado.
        if (s == null) return SizedBox(height: MediaQuery.paddingOf(context).bottom);
        return Material(
          color: l.surfaceAlt,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => Navigator.push(context, NowPlaying.route()),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    child: Row(
                      children: [
                        Hero(tag: 'cover', child: Cover(s, size: 44)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: l.ink),
                              ),
                              Text(
                                s.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: l.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: player.audio.playerStateStream,
                          builder: (_, snap) {
                            final playing = snap.data?.playing ?? false;
                            return IconButton(
                              tooltip: playing ? 'Pausar' : 'Reproducir',
                              onPressed: player.toggle,
                              icon: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 30,
                                color: l.ink,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: player.next,
                          icon: Icon(Icons.skip_next_rounded, size: 28, color: l.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
