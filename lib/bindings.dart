import 'package:get/get.dart';
import 'controllers/chess_controller.dart';
import 'controllers/options_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the OptionsController
    Get.put(OptionsController(), permanent: true);

    // Register the ChessController (lazy - created when needed)
    Get.lazyPut<ChessController>(() => ChessController(), fenix: true);
  }
}
