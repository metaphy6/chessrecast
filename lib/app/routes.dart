import 'package:get/get.dart';
import '../features/chess/presentation/pages/chess_game_page.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String home = '/';

  static List<GetPage> routes = [
    GetPage(
      name: home,
      page: () => const ChessGamePage(),
      binding: AppBindings(),
    ),
    GetPage(
      name: chess,
      page: () => const ChessGamePage(),
      binding: AppBindings(),
    ),
  ];
}
