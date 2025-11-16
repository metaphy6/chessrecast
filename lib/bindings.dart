import 'package:get/get.dart';
import 'management/options.dart';
import 'analytics/bot/bot_manager.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the BotManager (permanent - survives between games)
    Get.put(BotManager(), permanent: true);

    // Register the OptionsController
    Get.put(OptionsController(), permanent: true);

    // Note: Controller is now instantiated in the game page to support OnlineController
  }
}
