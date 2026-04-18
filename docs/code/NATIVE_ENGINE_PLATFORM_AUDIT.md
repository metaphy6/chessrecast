# Native Engine Platform Audit

Current native-engine status is a packaging and integration issue on some platforms, not a mixed "search in C plus search in Dart" architecture issue. Flutter runtime search is native-only now.

## Search Path Summary

- Android
  - Native engine is built through Gradle/CMake from `frontend/native/engine/CMakeLists.txt`.
  - `frontend/android/app/build.gradle.kts` configures `externalNativeBuild`, so `libchess_engine.so` should be packaged per ABI.
  - Expected result: native search runs in C. If the shared library is missing, engine search fails instead of falling back to a Dart searcher.

- Linux
  - Native engine is built and installed into the Linux bundle through `frontend/linux/CMakeLists.txt`.
  - `frontend/lib/engine/native.dart` searches the bundled `lib/` path, local build outputs, and `CHESSRECAST_NATIVE_ENGINE_LIB`.
  - Expected result: native search runs in bundled builds. Local dev/test failures are usually a missing `.so` or missing env override/build output.

- Windows
  - `frontend/lib/engine/native.dart` expects `chess_engine.dll`.
  - `frontend/windows/CMakeLists.txt` currently does not build or install the native engine target.
  - Current result: engine search is unavailable until packaging/integration is added.

- macOS
  - `frontend/lib/engine/native.dart` uses `DynamicLibrary.process()`, which requires the native engine symbols to be linked into the app process.
  - The macOS project files currently do not compile or link the native engine sources.
  - Current result: engine search is unavailable until linkage/integration is added.

- iOS
  - `frontend/lib/engine/native.dart` also uses `DynamicLibrary.process()`.
  - The iOS project currently has no native-engine build/link integration.
  - Current result: engine search is unavailable until linkage/integration is added.

## Architectural Note

When native loading succeeds, search is already happening in C.
Dart still applies the chosen move to the authoritative app state because the app tracks state that is not carried by plain FEN alone, including repetition history and mod-specific bookkeeping.

That means the main performance question by platform is:

- Android and Linux: usually load-path/build correctness.
- Windows, macOS, iOS: currently missing native integration, so native search remains unavailable there until packaging catches up.