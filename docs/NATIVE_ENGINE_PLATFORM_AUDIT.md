# Native Engine Platform Audit

Current native-engine status is a packaging and integration issue on some platforms, not a "search in C plus search in Dart" architecture issue.

## Search Path Summary

- Android
  - Native engine is built through Gradle/CMake from `frontend/native/engine/CMakeLists.txt`.
  - `frontend/android/app/build.gradle.kts` configures `externalNativeBuild`, so `libchess_engine.so` should be packaged per ABI.
  - Expected result: no Dart search fallback unless the native build fails or the APK is missing the matching ABI library.

- Linux
  - Native engine is built and installed into the Linux bundle through `frontend/linux/CMakeLists.txt`.
  - `frontend/lib/engine/native.dart` searches the bundled `lib/` path, local build outputs, and `CHESSRECAST_NATIVE_ENGINE_LIB`.
  - Expected result: no Dart search fallback in bundled builds. Fallback in local dev/test is usually a missing `.so` or missing env override/build output.

- Windows
  - `frontend/lib/engine/native.dart` expects `chess_engine.dll`.
  - `frontend/windows/CMakeLists.txt` currently does not build or install the native engine target.
  - Current result: fallback is caused by missing packaging/integration, not by the move pipeline itself.

- macOS
  - `frontend/lib/engine/native.dart` uses `DynamicLibrary.process()`, which requires the native engine symbols to be linked into the app process.
  - The macOS project files currently do not compile or link the native engine sources.
  - Current result: fallback is caused by missing linkage/integration.

- iOS
  - `frontend/lib/engine/native.dart` also uses `DynamicLibrary.process()`.
  - The iOS project currently has no native-engine build/link integration.
  - Current result: fallback is caused by missing linkage/integration.

## Architectural Note

When native loading succeeds, search is already happening in C.
Dart still applies the chosen move to the authoritative app state because the app tracks state that is not carried by plain FEN alone, including repetition history and mod-specific bookkeeping.

That means the main performance question by platform is:

- Android and Linux: usually load-path/build correctness.
- Windows, macOS, iOS: currently missing native integration, so fallback is expected.