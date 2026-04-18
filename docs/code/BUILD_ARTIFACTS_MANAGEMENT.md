# Build Artifacts Management

## Issue: Too Many Images in Request (Copilot Error)

### Problem Description
When using Copilot or GitHub integration with VS Code, you may encounter the error:
```
too many URL images in request (max 20)
```

This occurs because the `/frontend/build/` directory accumulates generated image files during the Flutter build process. These build artifacts duplicate source images across multiple density folders (2.0x, 3.0x) and intermediate build stages, causing the total image count to exceed 20 (the indexing limit for Copilot).

### Root Cause
- Flutter build output duplicates images in: `frontend/build/app/intermediates/flutter/{debug|release}/flutter_assets/`
- These are **generated files**, not source code
- They were accumulating locally even though they're properly ignored by `.gitignore`
- Copilot still indexes local files regardless of git status

### Solution: Proper Build Artifact Management

#### 1. Verify `.gitignore` Configuration
The repository already has the correct `.gitignore` entry:
```gitignore
/frontend/build/
```

This ensures build artifacts are **never committed** to the repository. ✅

#### 2. Clean Local Build Artifacts
If you encounter the Copilot image limit error:
```bash
rm -rf frontend/build
```

This removes all locally generated build artifacts without affecting source images stored in:
- `frontend/assets/images/boards/` (source images - **safe**)
- `frontend/android/app/src/main/res/mipmap-*` (Android resources - **safe**)
- `frontend/ios/Runner/Assets.xcassets/` (iOS resources - **safe**)
- `frontend/web/icons/` (Web assets - **safe**)

#### 3. Automatic Cleanup (Optional)
Add this to your development workflow to prevent accumulation:
```bash
# Clean build artifacts
flutter clean

# Rebuild as needed
flutter pub get
flutter build apk  # or web/ios/macos
```

### What's NOT Affected
Your source images remain **completely safe**:
- ✅ Chess board PNGs in `frontend/assets/images/boards/`
- ✅ App icons in `frontend/android/`, `frontend/ios/`, `frontend/macos/`, `frontend/web/`
- ✅ All source code and assets

### Prevention
1. **For developers**: Run `flutter clean` periodically or before committing
2. **For CI/CD**: Ensure build artifacts are cleaned between builds
3. **For VS Code**: The build directory won't be indexed since it's in `.gitignore`

### Related Files
- `.gitignore` - Configured to exclude build artifacts
- `frontend/build/` - Generated during build, safe to delete anytime

---
**Last Updated**: March 28, 2026  
**Status**: Active and permanent fix
