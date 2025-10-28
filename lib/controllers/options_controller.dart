import 'package:get/get.dart';
import '../modes/game_types.dart';

class OptionsController extends GetxController {
  final Rx<GameType> selectedGameType = GameType.classic.obs;

  void selectGameType(GameType gameType) {
    selectedGameType.value = gameType;
  }

  void startGame() {
    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
