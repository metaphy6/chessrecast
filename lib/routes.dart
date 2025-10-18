import 'package:get/get.dart';
import 'ui/game_page.dart';
import 'ui/start.dart';
import 'bindings.dart';

class AppRoutes {
  static const String chess = '/chess';
  static const String home = '/';

  static List<GetPage> routes = [
    GetPage(name: home, page: () => const StartPage(), binding: AppBindings()),
    GetPage(
      name: chess,
      page: () => const ChessGamePage(),
      binding: AppBindings(),
    ),
  ];
}
