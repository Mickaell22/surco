import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'library.dart';
import 'player.dart';
import 'settings.dart';
import 'stats.dart';
import 'theme.dart';
import 'ui/home.dart';

// ponytail: singletons globales en vez de un gestor de estado. La app tiene una
// sola biblioteca y un solo reproductor; si crece, pasar a InheritedNotifier.
final settings = Settings();
final stats = Stats();
final library = Library(settings);
final player = Player(stats, settings);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mickaell.surco.playback',
    androidNotificationChannelName: 'Reproduccion',
    androidNotificationOngoing: true,
    artDownscaleWidth: 256,
    artDownscaleHeight: 256,
  );
  await Future.wait([settings.load(), stats.load()]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SurcoApp());
}

class SurcoApp extends StatelessWidget {
  const SurcoApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (_, _) => MaterialApp(
          title: 'Surco',
          debugShowCheckedModeBanner: false,
          themeMode: settings.mode,
          theme: buildTheme(Brightness.light, settings.palette),
          darkTheme: buildTheme(Brightness.dark, settings.palette, pureBlack: settings.pureBlack),
          home: const Home(),
        ),
      );
}
