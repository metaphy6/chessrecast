import 'package:get/get.dart';
import '../modes/modes_enum.dart';

class OptionsController extends GetxController {
  final Rx<ModesEnum> selectedGameType = ModesEnum.classic.obs;

  void selectGameType(ModesEnum gameType) {
    selectedGameType.value = gameType;
  }

  void startGame() {
    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
