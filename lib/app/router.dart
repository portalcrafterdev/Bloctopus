import 'package:flutter/material.dart';

import '../models/save_data.dart';
import '../screens/game_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';

/// Route names. The game is four screens deep at most, so plain named routes
/// are enough; nothing here needs a router package.
class Routes {
  static const String splash = '/';
  static const String home = '/home';
  static const String map = '/map';
  static const String game = '/game';
  static const String settings = '/settings';
}

class GameArgs {
  final int levelId;
  final SaveData save;

  const GameArgs(this.levelId, this.save);
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case Routes.home:
      final save = settings.arguments as SaveData;
      return MaterialPageRoute<void>(builder: (_) => HomeScreen(save: save));
    case Routes.map:
      final save = settings.arguments as SaveData;
      return MaterialPageRoute<void>(builder: (_) => MapScreen(save: save));
    case Routes.game:
      final args = settings.arguments as GameArgs;
      return MaterialPageRoute<void>(
        builder: (_) => GameScreen(levelId: args.levelId, save: args.save),
      );
    case Routes.settings:
      final save = settings.arguments as SaveData;
      return MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(save: save),
      );
    case Routes.splash:
    default:
      return MaterialPageRoute<void>(builder: (_) => const SplashScreen());
  }
}
