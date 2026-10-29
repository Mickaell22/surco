import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../main.dart';
import '../mp4tags.dart';
import '../theme.dart';
import '../youtube.dart';

/// Bajar una canción de YouTube: pegar o compartir el link, elegir calidad,
/// recortar (despedidas, intros), revisar título/artista/portada/letra y guardar
/// en Music/Surco.
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key, this.initialUrl});
  final String? initialUrl;

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

enum _Step { link, loading, choose, downloading, edit, saving, done }

class _DownloadPageState extends State<DownloadPage> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _album = TextEditingController();
  var _step = _Step.link;
  String? _error;
  VideoInfo? _info;
  AudioOnlyStreamInfo? _stream;
  double _progress = 0;
  File? _file;
  RangeValues _range = const RangeValues(0, 1);
  Uint8List? _cover;
  String? _lyrics;
  bool _lyricsLoading = false, _useCover = true, _useLyrics = true;
  String? _savedPath;

  Duration get _length => _info?.video.duration ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl case final url?) {
      _url.text = url;
      _load();
    } else {
      // Si en el portapapeles hay un link de YouTube, ya queda puesto.
      Clipboard.getData(Clipboard.kTextPlain).then((d) {
        final url = d?.text == null ? null : findYoutubeUrl(d!.text!);
        if (url != null && mounted && _url.text.isEmpty) setState(() => _url.text = url);
      });
    }
  }

  @override
  void dispose() {
    player.endPreview();
    if (_file?.existsSync() ?? false) _file!.deleteSync();
    for (final c in [_url, _title, _artist, _album]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final url = findYoutubeUrl(_url.text);
    if (url == null) return setState(() => _error = 'Eso no parece un link de YouTube.');
    setState(() {
      _step = _Step.loading;
      _error = null;
    });
    try {
      final info = await fetchInfo(url);
      if (info.streams.isEmpty) throw 'YouTube no ofrece audio para este video.';
      final tags = guessTags(info.video.title, info.video.author);
      _title.text = tags.title;
      _artist.text = tags.artist;
      _album.text = tags.title;
      setState(() {
        _info = info;
        _stream = info.streams.first;
        _step = _Step.choose;
      });
      fetchCover(info.video).then((c) => mounted ? setState(() => _cover = c) : null);
    } catch (e) {
      setState(() {
        _step = _Step.link;
        _error = 'No se pudo leer el video: $e';
      });
    }
  }

  Future<void> _download() async {
    setState(() {
      _step = _Step.downloading;
      _progress = 0;
    });
    try {
      _file = await downloadAudio(_stream!, (p) => setState(() => _progress = p));
      setState(() {
        _range = RangeValues(0, _length.inSeconds.toDouble().clamp(1, double.infinity));
        _step = _Step.edit;
      });
      _findLyrics();
    } catch (e) {
      setState(() {
        _step = _Step.choose;
        _error = 'Falló la descarga: $e';
      });
    }
  }

  Future<void> _findLyrics() async {
    setState(() => _lyricsLoading = true);
    final l = await fetchLyrics(_title.text, _artist.text, _length);
    if (!mounted) return;
    setState(() {
      _lyrics = l;
      _lyricsLoading = false;
    });
  }

  Duration _sec(double s) => Duration(milliseconds: (s * 1000).round());

  void _listen({required bool end}) {
    final a = _range.start, b = _range.end;
    final from = end ? (b - 8).clamp(a, b) : a, to = end ? b : (a + 8).clamp(a, b);
    player.preview(_file!.path, _sec(from), _sec(to));
  }

  Future<void> _save() async {
    await player.endPreview();
    setState(() => _step = _Step.saving);
    try {
      final whole = _range.start == 0 && _range.end >= _length.inSeconds;
      _savedPath = await saveDownload(
        source: _file!,
        start: _sec(_range.start),
        end: whole ? null : _sec(_range.end),
        tags: Mp4Tags(
          title: _title.text.trim(),
          artist: _artist.text.trim(),
          album: _album.text.trim(),
          year: _info!.video.uploadDate?.year.toString(),
          lyrics: _useLyrics ? _lyrics : null,
          coverJpeg: _useCover ? _cover : null,
        ),
      );
      await library.scan();
      setState(() => _step = _Step.done);
    } catch (e) {
      setState(() {
        _step = _Step.edit;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    final pad = EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom);
    return Scaffold(
      appBar: AppBar(title: const Text('Descargar de YouTube')),
      body: ListView(
        padding: pad,
        children: [
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(e, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ...switch (_step) {
            _Step.link || _Step.loading => _linkStep(l),
            _Step.choose => _chooseStep(l),
            _Step.downloading => _busy(l, 'Descargando…', _progress),
            _Step.edit => _editStep(l),
            _Step.saving => _busy(l, 'Recortando y guardando…', null),
            _Step.done => _doneStep(l),
          },
        ],
      ),
    );
  }

  List<Widget> _linkStep(Ledger l) => [
    Text(
      'Pega el link del video, o en la app de YouTube toca Compartir y elige Surco.',
      style: TextStyle(color: l.inkSoft),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _url,
      decoration: const InputDecoration(labelText: 'Link de YouTube', prefixIcon: Icon(Icons.link_rounded)),
      keyboardType: TextInputType.url,
      onSubmitted: (_) => _load(),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: _step == _Step.loading ? null : _load,
      icon: _step == _Step.loading
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.search_rounded),
      label: const Text('Buscar'),
    ),
  ];

  Widget _header(Ledger l) {
    final v = _info!.video;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(
            dimension: 72,
            child: _cover == null ? ColoredBox(color: l.line) : Image.memory(_cover!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: l.ink),
              ),
              Text('${v.author} · ${fmtDur(v.duration)}', style: TextStyle(fontSize: 13, color: l.inkSoft)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _chooseStep(Ledger l) => [
    _header(l),
    const SizedBox(height: 20),
    Text(
      'Calidad',
      style: TextStyle(fontWeight: FontWeight.w600, color: l.ink),
    ),
    RadioGroup<AudioOnlyStreamInfo>(
      groupValue: _stream,
      onChanged: (s) => setState(() => _stream = s),
      child: Column(
        children: [
          for (final (i, s) in _info!.streams.indexed)
            RadioListTile<AudioOnlyStreamInfo>(
              value: s,
              contentPadding: EdgeInsets.zero,
              title: Text('${s.bitrate.kiloBitsPerSecond.round()} kbps${i == 0 ? ' · recomendada' : ''}'),
              subtitle: Text('AAC (.m4a) · ${s.size.totalMegaBytes.toStringAsFixed(1)} MB'),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download_rounded), label: const Text('Descargar')),
  ];

  List<Widget> _busy(Ledger l, String label, double? value) => [
    if (_info != null) _header(l),
    const SizedBox(height: 32),
    LinearProgressIndicator(value: value),
    const SizedBox(height: 12),
    Text(value == null ? label : '$label ${(value * 100).round()} %', style: TextStyle(color: l.inkSoft)),
  ];

  List<Widget> _editStep(Ledger l) {
    final max = _length.inSeconds.toDouble().clamp(1, double.infinity).toDouble();
    final kept = _sec(_range.end - _range.start);
    return [
      _header(l),
      const SizedBox(height: 20),
      Text(
        'Recortar',
        style: TextStyle(fontWeight: FontWeight.w600, color: l.ink),
      ),
      Text('Mueve los extremos para quitar intros o despedidas.', style: TextStyle(fontSize: 13, color: l.inkSoft)),
      RangeSlider(
        values: _range,
        max: max,
        divisions: max.round(),
        labels: RangeLabels(fmtDur(_sec(_range.start)), fmtDur(_sec(_range.end))),
        onChanged: (r) => setState(() => _range = r),
      ),
      Row(
        children: [
          Text(
            fmtDur(_sec(_range.start)),
            style: TextStyle(color: l.inkSoft, fontFeatures: tabular),
          ),
          const Spacer(),
          Text(
            'queda ${fmtDur(kept)}',
            style: TextStyle(color: l.muted, fontFeatures: tabular),
          ),
          const Spacer(),
          Text(
            fmtDur(_sec(_range.end)),
            style: TextStyle(color: l.inkSoft, fontFeatures: tabular),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _listen(end: false),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Escuchar inicio'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _listen(end: true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Escuchar final'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: 'Título'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _artist,
        decoration: const InputDecoration(labelText: 'Artista'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _album,
        decoration: const InputDecoration(labelText: 'Álbum'),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _useCover && _cover != null,
        onChanged: _cover == null ? null : (v) => setState(() => _useCover = v),
        title: const Text('Portada'),
        subtitle: Text(_cover == null ? 'No se pudo bajar la miniatura' : 'Miniatura del video, recortada cuadrada'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _useLyrics && _lyrics != null,
        onChanged: _lyrics == null ? null : (v) => setState(() => _useLyrics = v),
        title: const Text('Letra'),
        subtitle: Text(switch ((_lyricsLoading, _lyrics)) {
          (true, _) => 'Buscando en lrclib…',
          (_, null) => 'No se encontró',
          (_, final t?) => t.startsWith('[') ? 'Encontrada, sincronizada' : 'Encontrada',
        }),
        secondary: IconButton(
          tooltip: 'Buscar de nuevo con el título y artista de arriba',
          onPressed: _lyricsLoading ? null : _findLyrics,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _title.text.trim().isEmpty || _artist.text.trim().isEmpty ? null : _save,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Guardar en Música'),
      ),
    ];
  }

  List<Widget> _doneStep(Ledger l) {
    final song = library.byPath[_savedPath];
    return [
      _header(l),
      const SizedBox(height: 24),
      Text(
        'Guardada en Music/Surco.',
        style: TextStyle(color: l.ink, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      if (song != null)
        FilledButton.icon(
          onPressed: () => player.playList([song], 0),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Reproducir'),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          if (_file?.existsSync() ?? false) _file!.deleteSync();
          _url.clear();
          _step = _Step.link;
          _info = null;
          _file = null;
          _cover = null;
          _lyrics = null;
          _error = null;
        }),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Descargar otra'),
      ),
    ];
  }
}
