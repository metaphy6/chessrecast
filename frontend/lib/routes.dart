import 'package:get/get.dart';
import 'ui/game_page.dart';
import 'ui/game_mod_selection.dart';
import 'ui/play_options.dart';
import 'ui/bot_selection_page.dart';
import 'ui/online_bot_vs_bot_page.dart';
import 'ui/watch_engine_page.dart';
import 'analytics/custom/custom_board_setup.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String game = '/game';
  static const String home = '/';
  static const String playOptions = '/play-options';
  static const String customBoard = '/custom-board';
  static const String botSelection = '/bot-selection';
  static const String onlineBotVsBot = '/online-bot-vs-bot';
  static const String watchEngine = '/watch-engine';

  static List<GetPage> routes = [
    GetPage(
      name: home,
      page: () => const GameModSelectionPage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: playOptions,
      page: () => const PlayOptionsPage(),
      binding: AppBindings(),
    ),
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
      name: botSelection,
      page: () => const BotSelectionPage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: onlineBotVsBot,
      page: () => const OnlineBotVsBotPage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: watchEngine,
      page: () => const WatchEnginePage(),
      binding: AppBindings(),
    ),
  ];
}
