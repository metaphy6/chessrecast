import 'package:get/get.dart';
import 'management/options.dart';
import 'analytics/ai/ai_manager.dart';
import 'services/ai_service.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() async {
    // Register the OptionsController
    Get.put(OptionsController(), permanent: true);

    // Initialize and register AI Service
    final aiService = AIService.instance;
    try {
      await aiService.initialize();
      print('✓ AI Service initialized');
    } catch (e) {
      print('⚠️ AI Service initialization failed: $e');
      // Continue anyway - AI features will be disabled
    }

    // Register the AIManager (permanent - survives between games)
    Get.put(AIManager(), permanent: true);

    // Note: Controller is now instantiated in the game page to support OnlineController
  }
}
