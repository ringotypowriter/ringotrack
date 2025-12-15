# RingoTrack - AI Agent Development Guide

## Project Overview

RingoTrack is a cross-platform desktop application (Windows + macOS) for tracking drawing software usage time. It uses a GitHub-style calendar heatmap to visualize users' creative habits and dedication to various drawing applications. The app is built with Flutter and targets digital artists, illustrators, and manga creators.

## Technology Stack

- **Frontend**: Flutter (Dart) - Cross-platform desktop UI
- **Platform Integration**: 
  - Windows: win32 API via Dart FFI for foreground window tracking
  - macOS: Swift + AppKit for NSWorkspace notifications
- **Language**: Dart 3.10.1 with Flutter 3.38.3
- **Architecture**: Feature-based architecture with clear separation of concerns

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── app.dart                     # Application setup and configuration
├── providers.dart               # Centralized Riverpod providers
├── pages/
│   ├── clock_page.dart          # Clock display page
│   ├── dashboard_page.dart      # Main dashboard UI
│   └── settings_page.dart       # Settings configuration page
├── widgets/
│   ├── heatmap_color_scale.dart # Color scale for heatmaps
│   ├── logs_view_sheet.dart     # Logs display sheet
│   ├── ringo_heatmap.dart       # Calendar heatmap component
│   ├── ringo_hourly_line_heatmap.dart # Hourly line heatmap
│   └── year_selector.dart       # Year selection widget
├── theme/
│   └── app_theme.dart           # Application theming
├── platform/
│   ├── foreground_app_tracker.dart    # Platform-specific app tracking
│   ├── glass_tint_controller.dart     # Glass tint effects
│   ├── stroke_activity_tracker.dart   # Stroke activity monitoring
│   └── window_pin_controller.dart     # Window pinning controls
└── feature/
    ├── dashboard/
    │   ├── controllers/
    │   │   └── dashboard_preferences_controller.dart
    │   ├── models/
    │   │   └── dashboard_preferences.dart
    │   └── providers/
    │       └── dashboard_providers.dart
    ├── database/
    │   └── services/
    │       ├── app_database.dart       # Drift database definition
    │       └── app_database.g.dart     # Auto-generated database code
    ├── logging/
    │   ├── models/
    │   │   └── app_log_entry.dart
    │   └── services/
    │       └── app_log_service.dart
    ├── settings/
    │   ├── demo/
    │   │   └── controllers/            # Demo settings controllers
    │   ├── drawing_app/
    │   │   ├── controllers/            # Drawing app settings
    │   │   └── models/                 # Drawing app models
    │   └── theme/
    │       ├── controllers/            # Theme settings controllers
    │       └── models/                 # Theme models
    ├── update/
    │   └── github_release_service.dart # GitHub release checking
    └── usage/
        ├── models/
        │   ├── usage_hourly_backfill.dart
        │   └── usage_models.dart       # Core usage data models
        ├── providers/
        │   └── usage_providers.dart    # Usage-related providers
        ├── repositories/
        │   ├── demo_usage_repository.dart
        │   └── usage_repository.dart   # Usage data persistence
        └── services/
            ├── usage_analysis.dart     # Usage analytics
            └── usage_service.dart      # Usage tracking service
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
# Run tests
flutter test

# Analyze code
flutter analyze
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
