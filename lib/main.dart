import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/router.dart';
import 'app/theme.dart';

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

class BlocktopusApp extends StatelessWidget {
  const BlocktopusApp({super.key});

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
