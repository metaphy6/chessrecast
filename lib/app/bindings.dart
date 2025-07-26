import 'package:get/get.dart';
import '../features/chess/presentation/controllers/chess_controller.dart';
import '../features/game_options/presentation/controllers/game_options_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the GameOptionsController
    Get.put(GameOptionsController(), permanent: true);

    // Register the ChessController (lazy - created when needed)
    Get.lazyPut<ChessController>(() => ChessController(), fenix: true);
  }
}
