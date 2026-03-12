import 'package:get/get.dart';
import 'management/options.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() async {
    // Register the OptionsController
    Get.put(OptionsController(), permanent: true);

    // Note: Controller is now instantiated in the game page to support OnlineController
  }
}
