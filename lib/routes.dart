import 'package:get/get.dart';
import 'ui/game_page.dart';
import 'ui/start.dart';
import 'dev/dev_board_setup.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String game = '/game';
  static const String home = '/';
  static const String devBoard = '/dev-board';

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
      name: devBoard,
      page: () => const DevBoardSetupPage(),
      binding: AppBindings(),
    ),
  ];
}
