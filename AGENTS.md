# RingoTrack - AI Agent Development Guide

## Project Overview

RingoTrack is a cross-platform desktop application (Windows + macOS) for tracking drawing software usage time. It uses a GitHub-style calendar heatmap to visualize users' creative habits and dedication to various drawing applications. The app is built with Flutter and targets digital artists, illustrators, and manga creators.

## Technology Stack

- **Frontend**: Flutter (Dart) - Cross-platform desktop UI
- **Platform Integration**: 
  - Windows: win32 API via Dart FFI for foreground window tracking
  - macOS: Swift + AppKit for NSWorkspace notifications
- **Language**: Dart 3.10.1 with Flutter 3.38.3
- **Architecture**: Domain-driven design with clear separation of concerns

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── pages/
│   └── dashboard_page.dart      # Main dashboard UI
├── widgets/
│   └── ringo_heatmap.dart       # Calendar heatmap component
└── domain/
    ├── usage_models.dart        # Core data models and business logic
    └── usage_repository.dart    # Data persistence layer
```

## Core Architecture

### Data Models
- **AppUsageEntry**: Individual app usage record
- **DailyUsage**: Per-date usage aggregation with app breakdown
- **ForegroundAppEvent**: System event for app switching
- **UsageAggregator**: Core business logic for time tracking and aggregation

### Key Features
1. **Time Tracking**: Monitors foreground application usage
2. **Cross-day Handling**: Automatically splits usage across midnight boundaries
3. **Filtering**: Only tracks configured drawing applications
4. **Visualization**: GitHub-style heatmap with color-coded intensity
5. **Multi-view Support**: Merge view, per-app view, and grouping capabilities

## Build and Development Commands

```bash
# Install dependencies
flutter pub get

# Run the application
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze

# Build for production
flutter build windows  # Windows
flutter build macos    # macOS
```

## Testing Strategy

The project follows Test-Driven Development (TDD) with comprehensive unit tests:

- **UsageAggregator Tests** (`test/usage_aggregator_test.dart`): Core business logic validation
- **Widget Tests** (`test/widget_test.dart`): UI component testing
- **Repository Tests** (`test/usage_repository_test.dart`): Data persistence testing

### Key Test Cases
- TC-F-01: Single drawing app session tracking
- TC-F-02: Multiple sessions of same app
- TC-F-03: Cross-day usage splitting
- TC-F-04: Non-drawing app filtering
- TC-F-05: Dynamic app configuration

## Code Style Guidelines

- **Dart Style**: Follows official Dart style guide with `flutter_lints`
- **Naming**: Use descriptive names, prefer full words over abbreviations
- **Structure**: Keep widgets small and focused, separate business logic from UI
- **Comments**: Document complex algorithms and business rules

### Linting Configuration
- Uses `package:flutter_lints/flutter.yaml` as base
- Custom rules can be added in `analysis_options.yaml`

## Development Conventions

### UI/UX Principles
- Material Design 3 theming with green color scheme
- Responsive layout with proper padding and spacing
- Clear visual hierarchy with card-based design
- Hover interactions for detailed information

### Data Handling
- All time tracking uses `Duration` objects for precision
- Date handling respects local timezone boundaries
- Cross-day events are automatically split at midnight
- Data persistence uses in-memory storage (extensible to SQLite)

### Error Handling
- Graceful handling of missing data (empty states)
- Null safety throughout the codebase
- Defensive programming for edge cases

## Platform-Specific Considerations

### Windows Implementation
- Use `GetForegroundWindow()` and process enumeration
- App identification via executable names (e.g., `Photoshop.exe`)
- Requires win32 API integration via Dart FFI

### macOS Implementation  
- Use `NSWorkspace` notifications for app switching
- App identification via bundle identifiers (e.g., `com.adobe.photoshop`)
- Requires Flutter plugin with Swift implementation

## Deployment Process

1. **Development**: Local testing with `flutter run`
2. **Testing**: Run full test suite with `flutter test`
3. **Analysis**: Code quality check with `flutter analyze`
4. **Building**: Platform-specific builds with `flutter build`
5. **Distribution**: Package for respective app stores or direct distribution

## Security Considerations

- Application requires system-level permissions for foreground window monitoring
- User data is stored locally without external transmission
- No personal information is collected beyond app usage patterns
- Drawing software list is user-configurable for privacy

## Future Enhancements

- SQLite persistence for long-term data storage
- Advanced filtering and grouping options
- Export functionality for usage reports
- Plugin system for additional drawing software support
- Real-time sync across multiple devices