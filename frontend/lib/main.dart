import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'routes.dart';
import 'constants.dart';
import 'services/saved_games_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(SavedGamesService(), permanent: true);
  runApp(const ChessRecastApp());
}

class ChessRecastApp extends StatelessWidget {
  const ChessRecastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.brown.shade800,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      getPages: AppRoutes.routes,
    );
  }
}
