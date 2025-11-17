import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../analytics/bot/bot_manager.dart';

class OptionsController extends GetxController {
  final Rx<ModesEnum> selectedGameType = ModesEnum.classic.obs;

  void selectGameType(ModesEnum gameType) {
    final previous = selectedGameType.value;
    selectedGameType.value = gameType;
    // Only notify the previously-selected and newly-selected cards to avoid rebuilding all cards
    update(['mode_${previous.name}', 'mode_${gameType.name}']);
  }

  void startGame() {
    // Clear any bot configuration from previous games
    final botManager = Get.find<BotManager>();
    botManager.clear();

    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
