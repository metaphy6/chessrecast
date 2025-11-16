import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../analytics/bot/bot_manager.dart';

class OptionsController extends GetxController {
  final Rx<ModesEnum> selectedGameType = ModesEnum.classic.obs;

  void selectGameType(ModesEnum gameType) {
    selectedGameType.value = gameType;
    update(['mode_selection']);
  }

  void startGame() {
    // Clear any bot configuration from previous games
    final botManager = Get.find<BotManager>();
    botManager.clear();

    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
