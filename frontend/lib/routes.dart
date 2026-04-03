import 'package:get/get.dart';
import 'ui/game_page.dart';
import 'ui/selection.dart';
import 'ui/play_options.dart';
import 'ui/bot_selection_page.dart';
import 'ui/online_bot_vs_bot_page.dart';
import 'ui/watch_engine_page.dart';
import 'ui/play_engine_page.dart';
import 'ui/saved_games.dart';
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
  static const String playEngine = '/play-engine';
  static const String savedGames = '/saved-games';

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
    GetPage(name: chess, page: () => const GamePage(), binding: AppBindings()),
    GetPage(name: game, page: () => const GamePage(), binding: AppBindings()),
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
    GetPage(
      name: playEngine,
      page: () => const PlayEnginePage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: savedGames,
      page: () => const SavedGames(),
      binding: AppBindings(),
    ),
  ];
}
