import 'package:get/get.dart';
import '../../../../core/constants/game_types.dart';

class GameOptionsController extends GetxController {
  final Rx<GameType> selectedGameType = GameType.classic.obs;

  void selectGameType(GameType gameType) {
    selectedGameType.value = gameType;
    print('🎮 Game type selected: ${gameType.displayName}');
  }

  void startGame() {
    print('🚀 Starting game: ${selectedGameType.value.displayName}');
    Get.toNamed('/chess', arguments: {'gameType': selectedGameType.value});
  }
}
