import 'package:flutter/material.dart';

import '../main.dart';
import '../updater.dart';
import 'settings_page.dart' show appVersion;

/// Busca versión nueva. Con [quiet] (al abrir la app) solo avisa si la hay;
/// a mano también informa "ya tienes la última" o "sin conexión".
Future<void> checkForUpdate(BuildContext context, {bool quiet = false}) async {
  final r = await latestRelease();
  if (quiet) settings.markUpdateChecked();
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (r == null || !isNewer(r.version, appVersion)) {
    if (!quiet) {
      messenger.showSnackBar(
        SnackBar(
          persist: false,
          content: Text(r == null ? 'No se pudo revisar: sin conexión.' : 'Ya tienes la última versión ($appVersion).'),
        ),
      );
    }
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      persist: false,
      duration: const Duration(seconds: 8),
      content: Text('Surco ${r.version} está disponible.'),
      action: SnackBarAction(label: 'Ver', onPressed: () => showUpdate(context, r)),
    ),
  );
}

void showUpdate(BuildContext context, Release r) {
  final progress = ValueNotifier<double?>(null);
  var downloading = false;
  showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text('Surco ${r.version}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.notes.trim().isEmpty ? 'Versión nueva disponible.' : r.notes.trim()),
              if (downloading) ...[
                const SizedBox(height: 16),
                ValueListenableBuilder(
                  valueListenable: progress,
                  builder: (_, p, _) => LinearProgressIndicator(value: p),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Después')),
          FilledButton(
            onPressed: downloading
                ? null
                : () async {
                    setState(() => downloading = true);
                    try {
                      await downloadAndInstall(r, (p) => progress.value = p);
                      if (dialog.mounted) Navigator.pop(dialog);
                    } catch (e) {
                      setState(() => downloading = false);
                      if (dialog.mounted) {
                        ScaffoldMessenger.of(
                          dialog,
                        ).showSnackBar(SnackBar(persist: false, content: Text('No se pudo descargar: $e')));
                      }
                    }
                  },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    ),
  );
}
