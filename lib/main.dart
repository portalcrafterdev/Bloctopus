import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'game/audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  // The background is light, so the system icons drawn over it have to be
  // dark. `iconBrightness` describes the icons themselves; `statusBarBrightness`
  // describes what is behind them, which is why the two look contradictory.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BlocktopusApp());
}

/// Stateful only so it can watch the app lifecycle.
///
/// Flutter keeps running when the app is not on screen, and audioplayers keeps
/// playing with it, so the music carried on from a pocket unless something
/// told it not to. Nothing did: this is the app's only lifecycle observer.
class BlocktopusApp extends StatefulWidget {
  const BlocktopusApp({super.key});

  @override
  State<BlocktopusApp> createState() => _BlocktopusAppState();
}

class _BlocktopusAppState extends State<BlocktopusApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Deliberately not [AppLifecycleState.inactive]. That one fires for
      // anything that merely covers the app for a moment - the notification
      // shade, the app switcher, a permission dialog - and cutting the music
      // for each of those would stutter it during ordinary use.
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        AudioService.instance.handleAppHidden();
      case AppLifecycleState.resumed:
        AudioService.instance.handleAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blocktopus',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: Routes.splash,
      onGenerateRoute: onGenerateRoute,
      builder: (context, child) {
        // The board layout assumes a sane text scale.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1).clamp(0.85, 1.25),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
