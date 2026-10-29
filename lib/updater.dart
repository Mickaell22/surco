import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'native.dart';

/// Repo público de donde salen las versiones (el mismo del README).
const releasesApi = 'https://api.github.com/repos/Mickaell22/surco/releases/latest';

typedef Release = ({String version, String notes, Map<String, String> apks});

/// Compara versiones "1.2.10" > "1.2.9" número por número.
bool isNewer(String candidate, String current) {
  List<int> parts(String v) => [for (final p in v.replaceFirst('v', '').split('.')) int.tryParse(p) ?? 0];
  final a = parts(candidate), b = parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Último release publicado, o null si no hay red o GitHub no responde.
Future<Release?> latestRelease() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(Uri.parse(releasesApi));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    return (
      version: (j['tag_name'] as String).replaceFirst('v', ''),
      notes: (j['body'] as String?) ?? '',
      apks: {
        for (final a in (j['assets'] as List).cast<Map<String, dynamic>>())
          if ((a['name'] as String).endsWith('.apk')) a['name'] as String: a['browser_download_url'] as String,
      },
    );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Baja el APK que corresponde a la arquitectura del teléfono y abre el
/// instalador de Android. [onProgress] va de 0 a 1.
Future<void> downloadAndInstall(Release r, void Function(double) onProgress) async {
  final abi = await primaryAbi();
  final url = r.apks['surco-$abi.apk'] ?? r.apks['surco-arm64-v8a.apk'] ?? r.apks.values.first;
  final file = File('${(await getTemporaryDirectory()).path}/surco-update.apk');
  final client = HttpClient();
  try {
    final res = await (await client.getUrl(Uri.parse(url))).close();
    if (res.statusCode != 200) throw HttpException('GitHub respondió ${res.statusCode}');
    final sink = file.openWrite();
    var got = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (res.contentLength > 0) onProgress(got / res.contentLength);
    }
    await sink.close();
  } finally {
    client.close();
  }
  await installApk(file.path);
}
