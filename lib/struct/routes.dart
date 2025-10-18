import 'package:get/get.dart';
import '../game/presentation/pages/game_page.dart';
import '../game/options/presentation/pages/game_options_page.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String home = '/';
  static const String gameOptions = '/game-options';

  static List<GetPage> routes = [
    GetPage(
      name: home,
      page: () => const GameOptionsPage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: gameOptions,
      page: () => const GameOptionsPage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: chess,
      page: () => const ChessGamePage(),
      binding: AppBindings(),
    ),
  ];
}
