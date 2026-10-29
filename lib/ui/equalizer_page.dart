import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../main.dart';
import '../settings.dart';
import '../theme.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  void _save(void Function(Settings s) change) {
    settings.update(change);
    player.applyEq();
  }

  void _preset(EqPreset p, AndroidEqualizerParameters params) => _save((s) {
    s.eqPreset = p;
    s.eqEnabled = true;
    s.eqGains = [
      for (final b in params.bands) p.gainAt(b.centerFrequency).clamp(params.minDecibels, params.maxDecibels),
    ];
  });

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ecualizador'),
        actions: [
          ListenableBuilder(
            listenable: settings,
            builder: (_, _) => Switch(value: settings.eqEnabled, onChanged: (v) => _save((s) => s.eqEnabled = v)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<AndroidEqualizerParameters>(
        future: player.equalizer.parameters,
        builder: (context, snap) {
          final params = snap.data;
          if (params == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Reproduce una canción una vez para activar el ecualizador del teléfono.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: l.inkSoft),
                ),
              ),
            );
          }
          return ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Opacity(
              opacity: settings.eqEnabled ? 1 : .45,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in EqPreset.values.where((p) => p != EqPreset.personal))
                        ChoiceChip(
                          label: Text(p.label),
                          selected: settings.eqPreset == p,
                          onSelected: (_) => _preset(p, params),
                        ),
                      if (settings.eqPreset == EqPreset.personal)
                        const ChoiceChip(label: Text('Personalizado'), selected: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 260,
                    child: Row(children: [for (final b in params.bands) Expanded(child: _Band(b, params))]),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Volumen extra',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: l.ink),
                  ),
                  Text(
                    'Sube el volumen por encima del máximo del teléfono. Con mucho puede distorsionar.',
                    style: TextStyle(fontSize: 13, color: l.inkSoft),
                  ),
                  Slider(
                    value: settings.loudness,
                    max: 10,
                    divisions: 10,
                    label: '+${settings.loudness.round()} dB',
                    onChanged: (v) => settings.update((s) => s.loudness = v),
                    onChangeEnd: (_) => player.applyEq(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band(this.band, this.params);
  final AndroidEqualizerBand band;
  final AndroidEqualizerParameters params;

  String get _freq {
    final hz = band.centerFrequency;
    return hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)} kHz' : '${hz.round()} Hz';
  }

  @override
  Widget build(BuildContext context) {
    final l = Ledger.of(context);
    final gains = settings.eqGains;
    final g = band.index < gains.length ? gains[band.index] : 0.0;
    return Column(
      children: [
        Text('${g > 0 ? '+' : ''}${g.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: l.inkSoft, fontFeatures: tabular)),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: g.clamp(params.minDecibels, params.maxDecibels),
              min: params.minDecibels,
              max: params.maxDecibels,
              onChanged: (v) {
                band.setGain(v);
                settings.update((s) {
                  s.eqPreset = EqPreset.personal;
                  s.eqEnabled = true;
                  s.eqGains = [
                    for (var i = 0; i < params.bands.length; i++)
                      i == band.index ? v : (i < s.eqGains.length ? s.eqGains[i] : 0.0),
                  ];
                });
              },
              onChangeEnd: (_) => player.applyEq(),
            ),
          ),
        ),
        Text(_freq, style: TextStyle(fontSize: 11, color: l.muted)),
      ],
    );
  }
}
