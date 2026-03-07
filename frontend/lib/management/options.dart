import 'package:get/get.dart';
import '../mods/mods_enum.dart';
import 'utils.dart';

class OptionsController extends GetxController {
  final Rx<ModsEnum> selectedGameType = ModsEnum.classic.obs;

  void selectGameType(ModsEnum gameType) {
    final previous = selectedGameType.value;
    selectedGameType.value = gameType;
    // Only notify the previously-selected and newly-selected cards to avoid rebuilding all cards
    updateModeSelection(this, previous, gameType);
  }

  void startGame() {
    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
