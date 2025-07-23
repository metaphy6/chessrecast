# Chess Recast

A novel chess game that introduces new moves to existing pieces while maintaining the same board and pieces as traditional chess. Built with Flutter for cross-platform compatibility.

## Project Overview

Chess Recast is an innovative take on the classic game of chess. While it uses the traditional 8x8 board and the same piece set (King, Queen, Rook, Bishop, Knight, Pawn), it introduces exciting new movement rules that create fresh strategic possibilities.

## Features

### Current Implementation (v1.0.0)
- ✅ Standard chess board with 8x8 grid
- ✅ All traditional chess pieces with Unicode symbols
- ✅ Basic chess rules and piece movement
- ✅ Turn-based gameplay
- ✅ Move validation
- ✅ Check and checkmate detection
- ✅ Clean, responsive UI that works on multiple screen sizes
- ✅ GetX state management for efficient performance
- ✅ Cross-platform support (Android, iOS, Windows, macOS, Linux, Web)

### Upcoming Features (Chess Recast Rules)
- 🔄 New piece movement patterns
- 🔄 Innovative game mechanics
- 🔄 Extended rule variations
- 🔄 Advanced game analysis
- 🔄 Move history and replay
- 🔄 Game saving and loading

## Architecture

This project follows clean architecture principles with separation of concerns:

```
lib/
├── app/                    # App configuration
│   ├── bindings.dart      # Dependency injection
│   └── routes.dart        # Navigation routes
├── core/                  # Core utilities
│   ├── constants/         # App constants
│   └── utils/            # Utility functions
└── features/             # Feature modules
    └── chess/            # Chess game feature
        ├── data/         # Data layer (future use)
        ├── domain/       # Business logic
        │   ├── entities/ # Domain entities
        │   ├── enums/    # Enumerations
        │   └── services/ # Domain services
        └── presentation/ # UI layer
            ├── controllers/ # State management
            ├── pages/      # Screen widgets
            └── widgets/    # Reusable widgets
```

## Technology Stack

- **Framework**: Flutter 3.8.1+
- **State Management**: GetX 4.7.2
- **Language**: Dart
- **Architecture**: Clean Architecture with separation of concerns
- **Testing**: Flutter Test framework

## Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio or VS Code
- Android SDK (for Android development)
- Xcode (for iOS development, macOS only)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd chessrecast
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   # For Android emulator
   flutter run -d <device-id>
   
   # For web
   flutter run -d chrome
   
   # For desktop
   flutter run -d windows
   flutter run -d macos
   flutter run -d linux
   ```

### Development

To run on Android emulator:
```bash
flutter emulators --launch <emulator-id>
flutter run -d emulator-5554
```

To run tests:
```bash
flutter test
```

To analyze code:
```bash
flutter analyze
```

## Game Rules

### Current Rules (Standard Chess)
The current implementation follows standard chess rules:
- Traditional piece movements
- Castling, en passant, and pawn promotion
- Check, checkmate, and stalemate detection
- Turn-based play (White moves first)

### Future Rules (Chess Recast)
*Details will be added as new rules are implemented*

## Contributing

This project is currently in development. Contributions will be welcome once the initial Chess Recast rules are implemented.

## Development Roadmap

### Phase 1: Foundation ✅
- [x] Project setup and architecture
- [x] Basic chess implementation
- [x] UI components and board visualization
- [x] Standard chess rules

### Phase 2: Chess Recast Rules 🔄
- [ ] Define new movement patterns
- [ ] Implement extended piece abilities
- [ ] Add new game mechanics
- [ ] Comprehensive testing

### Phase 3: Enhancement
- [ ] AI opponent
- [ ] Online multiplayer
- [ ] Game analysis tools
- [ ] Tournament mode

## License

*License information will be added*

## Contact

*Contact information will be added*
