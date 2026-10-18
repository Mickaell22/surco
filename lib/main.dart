import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'library.dart';
import 'player.dart';
import 'theme.dart';
import 'ui/home.dart';

// ponytail: dos singletons globales en vez de un gestor de estado. La app tiene
// una sola biblioteca y un solo reproductor; si crece, pasar a InheritedNotifier.
final library = Library();
final player = Player();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mickaell.surco.playback',
    androidNotificationChannelName: 'Reproduccion',
    androidNotificationOngoing: true,
    artDownscaleWidth: 256,
    artDownscaleHeight: 256,
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SurcoApp());
}

class SurcoApp extends StatelessWidget {
  const SurcoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Surco',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Home(),
      );
}
