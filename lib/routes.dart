import 'package:get/get.dart';
import 'ui/game_page.dart';
import 'ui/start.dart';
import 'ui/bot_setup.dart';
import 'analytics/custom/custom_board_setup.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String game = '/game';
  static const String home = '/';
  static const String customBoard = '/custom-board';
  static const String botSetup = '/bot-setup';

  static List<GetPage> routes = [
    GetPage(name: home, page: () => const StartPage(), binding: AppBindings()),
    GetPage(
      name: chess,
      page: () => const ChessGamePage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: game,
      page: () => const ChessGamePage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: customBoard,
      page: () => const CustomBoardSetupPage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: botSetup,
      page: () => const BotSetupScreen(),
      binding: AppBindings(),
    ),
  ];
}
