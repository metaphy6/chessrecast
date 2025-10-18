import 'package:get/get.dart';
import '../game/presentation/controllers/controller.dart';
import '../game/options/presentation/controllers/game_options_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the GameOptionsController
    Get.put(GameOptionsController(), permanent: true);

    // Register the ChessController (lazy - created when needed)
    Get.lazyPut<ChessController>(() => ChessController(), fenix: true);
  }
}
