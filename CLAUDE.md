# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ModelMana is a native macOS menu bar application for managing API provider configurations for AI models (Claude, Zhipu). It provides quick switching between providers and API keys via the menu bar, with a settings window for full configuration management.

**Platform**: macOS 14.6+
**Language**: Swift 5.0
**Framework**: SwiftUI
**Bundle ID**: `com.zafei.ModelMana`

## Build and Development Commands

This is an Xcode project. Use Xcode or `xcodebuild` for development.

### Building
```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

### Running Tests
```bash
# All tests
xcodebuild test -project ModelMana.xcodeproj -scheme ModelMana

# Unit tests only
xcodebuild test -project ModelMana.xcodeproj -scheme ModelMana -only-testing:ModelManaTests

# UI tests only
xcodebuild test -project ModelMana.xcodeproj -scheme ModelMana -only-testing:ModelManaUITests
```

## Architecture

ModelMana follows an **MVVM architecture** with a service layer:

### State Management
- **`AppState`** (ViewModels/AppState.swift): Singleton using `@Observable` macro that holds the central `AppConfiguration` instance

### Services Layer
- **`ConfigService`**: Manages JSON configuration at `~/.modelmana/config.json` - handles saving/loading with pretty-printed JSON
- **`SettingsFileService`**: Updates Claude's settings file (`~/.claude/settings.json`) with `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`
- **`EnvService`**: Simple environment variable reader

### Models
- **`Provider` enum**: Defines supported providers (`.zhipu`, `.claude`) with fixed string IDs, base URLs, and environment variable keys
- **`ApiKeyConfig`**: Individual API key with UUID, name, masked key value
- **`ProviderConfig`**: Aggregates provider with list of API keys
- **`AppConfiguration`**: Main config with selected provider/key tracking and list of provider configs

### Views
- **`ProviderListView`**: Menu bar dropdown showing current provider, with provider/key selection menus and settings gear
- **`SettingsWindowView`**: Settings window with provider cards for CRUD operations on providers and API keys

## App Structure

```
ModelMana/
├── ModelManaApp.swift          # App entry point with MenuBarExtra + Settings window
├── Models/                     # Data models (Provider, ProviderConfig, etc.)
├── Services/                   # ConfigService, SettingsFileService, EnvService
├── ViewModels/                 # AppState singleton
├── Views/                      # SwiftUI views (ProviderListView, SettingsWindowView)
└── Assets.xcassets/            # Icons (claude.imageset, zhipu.imageset)
```

## Configuration Files

- **App Config**: `~/.modelmana/config.json` - stores all app configuration
- **Claude Settings**: `~/.claude/settings.json` - updated by SettingsFileService for Claude CLI

## Adding a New Provider

1. Add case to `Provider` enum with `id`, `baseUrl`, and `envKey`
2. Add provider icon to Assets.xcassets
3. No code changes needed elsewhere - the UI automatically supports new providers via the enum

## Entitlements

The app has sandbox disabled (`com.apple.security.app-sandbox: false`) to allow file system access for configuration management.
