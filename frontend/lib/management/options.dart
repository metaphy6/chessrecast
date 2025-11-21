import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../analytics/bot/bot_manager.dart';
import 'utils.dart';

class OptionsController extends GetxController {
  final Rx<ModesEnum> selectedGameType = ModesEnum.classic.obs;

  void selectGameType(ModesEnum gameType) {
    final previous = selectedGameType.value;
    selectedGameType.value = gameType;
    // Only notify the previously-selected and newly-selected cards to avoid rebuilding all cards
    updateModeSelection(this, previous, gameType);
  }

  void startGame() {
    // Clear any bot configuration from previous games
    Get.find<BotManager>().clear();
    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
