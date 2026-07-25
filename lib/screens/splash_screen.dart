import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../models/save_data.dart';
import '../widgets/mascot_view.dart';
import 'home_screen.dart';

/// Loads the save blob and warms the audio pool, then hands over to the map.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final save = await SaveData.load();
    Haptics.settings = save.settings;
    await AudioService.instance.init(save.settings);

    // Never flash: hold the splash for at least 700ms.
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 700);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted) return;
    // Replaces the splash, so there is no result to wait for.
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, a, _) => FadeTransition(
            opacity: a,
            child: HomeScreen(save: save),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotView(size: 148, state: MascotState.idle),
            SizedBox(height: 26),
            Text('Blocktopus', style: T.displayOnBg),
            SizedBox(height: 6),
            Text('Block puzzle', style: T.dimOnBg),
          ],
        ),
      ),
    );
  }
}
