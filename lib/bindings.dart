import 'package:get/get.dart';
import 'management/controller.dart';
import 'management/options.dart';
import 'analytics/bot/bot_manager.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the BotManager (permanent - survives between games)
    Get.put(BotManager(), permanent: true);

    // Register the OptionsController
    Get.put(OptionsController(), permanent: true);

    // Register the Controller (lazy - created when needed)
    Get.lazyPut<Controller>(() => Controller(), fenix: true);
  }
}
