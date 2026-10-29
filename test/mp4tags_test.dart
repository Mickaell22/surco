import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surco/mp4tags.dart';

Uint8List box(String type, List<int> body) => Uint8List.fromList([
      ...(ByteData(4)..setUint32(0, body.length + 8)).buffer.asUint8List(),
      ...latin1.encode(type),
      ...body,
    ]);

List<int> u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

void main() {
  test('escribe etiquetas, mueve moov adelante y corrige stco', () {
    // ftyp, mdat con dos "muestras" conocidas, moov al final con stco.
    final ftyp = box('ftyp', [...latin1.encode('M4A '), 0, 0, 0, 0, ...latin1.encode('M4A isom')]);
    final mdat = box('mdat', [...latin1.encode('AAAA'), ...latin1.encode('BBBB')]);
    final a = ftyp.length + 8, b = a + 4; // offsets absolutos de cada muestra
    final stco = box('stco', [0, 0, 0, 0, ...u32(2), ...u32(a), ...u32(b)]);
    final moov = box('moov', box('trak', box('mdia', box('minf', box('stbl', stco)))));
    final file = Uint8List.fromList([...ftyp, ...mdat, ...moov]);

    final out = writeMp4Tags(
      file,
      Mp4Tags(title: 'Canción', artist: 'Artista', album: 'Álbum', lyrics: 'letra', coverJpeg: Uint8List(3)),
    );

    // Después de moov vienen las muestras: los offsets nuevos deben apuntarles.
    final d = ByteData.sublistView(out);
    final i = latin1.decode(out, allowInvalid: true).indexOf('stco') + 4 + 8;
    expect(ascii.decode(out.sublist(d.getUint32(i), d.getUint32(i) + 4)), 'AAAA');
    expect(ascii.decode(out.sublist(d.getUint32(i + 4), d.getUint32(i + 4) + 4)), 'BBBB');
    expect(latin1.decode(out.sublist(4, 8)), 'ftyp');

    // La biblioteca (audio_metadata_reader) lee lo escrito.
    final f = File('${Directory.systemTemp.createTempSync().path}/t.m4a')..writeAsBytesSync(out);
    final meta = readMetadata(f, getImage: false);
    expect(meta.title, 'Canción');
    expect(meta.artist, 'Artista');
    expect(meta.album, 'Álbum');
  });

  test('rechaza MP4 fragmentado', () {
    final file = Uint8List.fromList([...box('ftyp', []), ...box('moov', []), ...box('moof', [])]);
    expect(() => writeMp4Tags(file, const Mp4Tags(title: 't', artist: 'a')), throwsFormatException);
  });
}
