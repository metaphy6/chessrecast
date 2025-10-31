import 'package:get/get.dart';
import 'management/controller.dart';
import 'management/options.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register the OptionsController
    Get.put(OptionsController(), permanent: true);

    // Register the Controller (lazy - created when needed)
    Get.lazyPut<Controller>(() => Controller(), fenix: true);
  }
}
