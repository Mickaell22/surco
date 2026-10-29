import 'dart:convert';
import 'dart:typed_data';

/// Etiquetas estilo iTunes para un .m4a: las mismas que usa la música bajada en
/// la PC (mutagen) y que la biblioteca ya sabe leer.
class Mp4Tags {
  const Mp4Tags({required this.title, required this.artist, this.album, this.year, this.lyrics, this.coverJpeg});
  final String title, artist;
  final String? album, year, lyrics;
  final Uint8List? coverJpeg;
}

class _Box {
  _Box(this.type, this.start, this.size, this.header);
  final String type;
  final int start, size, header;
  int get end => start + size;
}

List<_Box> _boxes(ByteData d, int from, int to) {
  final out = <_Box>[];
  var p = from;
  while (p + 8 <= to) {
    var size = d.getUint32(p);
    var header = 8;
    if (size == 1) {
      size = d.getUint64(p + 8);
      header = 16;
    } else if (size == 0) {
      size = to - p;
    }
    if (size < header || p + size > to) throw const FormatException('MP4 dañado');
    out.add(_Box(ascii.decode(d.buffer.asUint8List(d.offsetInBytes + p + 4, 4), allowInvalid: true), p, size, header));
    p += size;
  }
  return out;
}

Uint8List _box(String type, List<int> body) {
  final b = BytesBuilder(copy: false)
    ..add((ByteData(4)..setUint32(0, body.length + 8)).buffer.asUint8List())
    ..add(latin1.encode(type))
    ..add(body);
  return b.toBytes();
}

/// item de ilst con un atom "data" del [kind] dado (1 = texto UTF-8, 13 = JPEG).
Uint8List _item(String type, List<int> payload, int kind) =>
    _box(type, _box('data', [0, 0, 0, kind, 0, 0, 0, 0, ...payload]));

Uint8List _udta(Mp4Tags t) {
  final items = <int>[
    ..._item('©nam', utf8.encode(t.title), 1),
    ..._item('©ART', utf8.encode(t.artist), 1),
    ..._item('aART', utf8.encode(t.artist), 1),
    if (t.album case final a? when a.isNotEmpty) ..._item('©alb', utf8.encode(a), 1),
    if (t.year case final y? when y.isNotEmpty) ..._item('©day', utf8.encode(y), 1),
    if (t.lyrics case final l? when l.isNotEmpty) ..._item('©lyr', utf8.encode(l), 1),
    if (t.coverJpeg case final c?) ..._item('covr', c, 13),
  ];
  // hdlr "mdir/appl": sin él varios lectores ignoran el ilst.
  final hdlr = _box('hdlr', [0, 0, 0, 0, 0, 0, 0, 0, ...latin1.encode('mdirappl'), 0, 0, 0, 0, 0, 0, 0, 0, 0]);
  final meta = _box('meta', [0, 0, 0, 0, ...hdlr, ..._box('ilst', items)]);
  return _box('udta', meta);
}

const _containers = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts'};

/// Devuelve el archivo con las etiquetas [t] dentro de moov/udta. Reordena a
/// ftyp, moov, resto (el moov adelante deja reproducir mientras carga) y corrige
/// los offsets de stco/co64. No admite MP4 fragmentado (moof): pasarlo antes por
/// el recorte nativo, que siempre deja uno común.
Uint8List writeMp4Tags(Uint8List file, Mp4Tags t) {
  final d = ByteData.sublistView(file);
  final top = _boxes(d, 0, file.length);
  if (top.any((b) => b.type == 'moof')) throw const FormatException('MP4 fragmentado');
  final moov = top.firstWhere((b) => b.type == 'moov', orElse: () => throw const FormatException('Sin moov'));

  // Nuevo moov: los mismos hijos menos el udta viejo, más el nuevo. También
  // sale el moov/meta que agrega MediaMuxer (com.android.version): con él
  // mutagen y otros lectores no encuentran las etiquetas.
  final udta = _udta(t);
  final kids = _boxes(
    d,
    moov.start + moov.header,
    moov.end,
  ).where((b) => b.type != 'udta' && b.type != 'meta').toList();
  final moovBody = BytesBuilder(copy: false);
  for (final k in kids) {
    moovBody.add(Uint8List.sublistView(file, k.start, k.end));
  }
  moovBody.add(udta);
  final newMoov = _box('moov', moovBody.toBytes());

  // Orden nuevo y dónde arranca cada caja de nivel superior.
  final rest = top.where((b) => b.type != 'moov' && b.type != 'free' && b.type != 'skip').toList();
  final order = [...rest.where((b) => b.type == 'ftyp'), moov, ...rest.where((b) => b.type != 'ftyp')];
  final newStart = <_Box, int>{};
  var pos = 0;
  for (final b in order) {
    newStart[b] = pos;
    pos += identical(b, moov) ? newMoov.length : b.size;
  }
  int remap(int offset) {
    final b = top.firstWhere(
      (b) => offset >= b.start && offset < b.end,
      orElse: () => throw const FormatException('Offset fuera del archivo'),
    );
    final s = newStart[b];
    if (s == null) throw const FormatException('Offset apunta a una caja descartada');
    return offset - b.start + s;
  }

  // Corrige stco/co64 dentro del moov nuevo.
  final md = ByteData.sublistView(newMoov);
  void walk(int from, int to) {
    for (final b in _boxes(md, from, to)) {
      final body = b.start + b.header;
      if (_containers.contains(b.type)) {
        walk(body, b.end);
      } else if (b.type == 'stco' || b.type == 'co64') {
        final n = md.getUint32(body + 4);
        for (var i = 0; i < n; i++) {
          if (b.type == 'stco') {
            final at = body + 8 + i * 4;
            md.setUint32(at, remap(md.getUint32(at)));
          } else {
            final at = body + 8 + i * 8;
            md.setUint64(at, remap(md.getUint64(at)));
          }
        }
      }
    }
  }

  walk(8, newMoov.length);

  final out = BytesBuilder(copy: false);
  for (final b in order) {
    out.add(identical(b, moov) ? newMoov : Uint8List.sublistView(file, b.start, b.end));
  }
  return out.toBytes();
}
