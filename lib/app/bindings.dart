import 'package:get/get.dart';
import '../features/chess/presentation/controllers/chess_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the ChessController as a singleton
    Get.put(ChessController(), permanent: true);
  }
}
