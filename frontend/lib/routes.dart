import 'package:get/get.dart';
import 'ui/game_page.dart';
import 'ui/start.dart';
import 'ui/bot_setup.dart';
import 'ui/bot_selection_page.dart';
import 'ui/online_bot_vs_bot_page.dart';
import 'ui/ai_setup.dart';
import 'ui/training_viewer.dart';
import 'ui/live_training_viewer.dart';
import 'analytics/custom/custom_board_setup.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String game = '/game';
  static const String home = '/';
  static const String customBoard = '/custom-board';
  static const String botSetup = '/bot-setup';
  static const String botSelection = '/bot-selection';
  static const String onlineBotVsBot = '/online-bot-vs-bot';
  static const String aiSetup = '/ai-setup';
  static const String trainingViewer = '/training-viewer';
  static const String liveTrainingViewer = '/live-training-viewer';

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
      name: aiSetup,
      page: () => const AISetupScreen(),
      binding: AppBindings(),
    ),
    GetPage(
      name: trainingViewer,
      page: () => const TrainingViewerScreen(),
      binding: AppBindings(),
    ),
    GetPage(
      name: liveTrainingViewer,
      page: () => const LiveTrainingViewer(),
      binding: AppBindings(),
    ),
  ];
}
