# ProviderListView Refactoring Design

**Date:** 2025-01-17
**Status:** Approved
**Goal:** Better code organization through component extraction

## Overview

The current `ProviderListView.swift` file has grown to ~1315 lines with many components mixed together. This design document outlines a refactoring plan to improve organization by extracting components into separate, focused files.

## File Structure

```
Views/ProviderList/
├── ProviderListView.swift              # Main coordinator view
├── Components/
│   ├── ProviderIcon.swift              # Provider icon display
│   ├── ProviderButton.swift            # Selection button
│   ├── ActiveKeySection.swift          # Current provider display
│   └── ProgressViews.swift             # Quota progress views
├── Dropdown/
│   ├── ApiKeyDropdownPanel.swift       # General provider dropdown
│   └── ClaudeDropdownPanel.swift       # Claude-specific dropdown
├── Claude/
│   ├── ClaudeCredentialCard.swift      # Credential card component
│   ├── ClaudeCostView.swift            # Cost display view
│   └── ClaudeLoginComponents.swift     # Login button/status
└── Shared/
    ├── HoverButton.swift               # Reusable hover button wrapper
    ├── BlackProgressStyle.swift        # Progress view style
    ├── PreferenceKeys.swift            # Preference keys
    └── ViewExtensions.swift            # View extensions (onPressGesture)
```

## Component Responsibilities

### ProviderListView (Main)
- **Role:** Thin coordinator
- **Holds:** Dropdown state (`@State` variables)
- **Computes:** `currentProviderConfig`, `visibleProviders`
- **Manages:** `NSPanel` lifecycle (show/hide dropdown)
- **Handles:** Click-outside-to-close via event monitor

### Components/

| Component | Responsibility |
|-----------|----------------|
| `ProviderIcon` | Pure view. Given providerId + size, returns correct image |
| `ProviderButton` | Wraps `HoverButton` with provider icon + name + chevron |
| `ActiveKeySection` | Displays current provider + credential info with quota. Reads from `AppState` |
| `ProgressViews` | Contains `QuotaProgressView` for displaying quota status (loading/success/error) |

### Dropdown/

| Component | Responsibility |
|-----------|----------------|
| `ApiKeyDropdownPanel` | Non-Claude provider dropdown. Reuses `HoverButton` and quota views |
| `ClaudeDropdownPanel` | Claude-specific card-based dropdown. Uses `ClaudeCredentialCard` |

### Claude/

| Component | Responsibility |
|-----------|----------------|
| `ClaudeCredentialCard` | Card with circular progress, title, subtitle, action button |
| `ClaudeCostView` | Cost display for Claude Console (currently unused, kept for future) |
| `ClaudeLoginComponents` | Contains `ClaudeLoginButton` and `ClaudeLoginStatusView` |

### Shared/

| Component | Responsibility |
|-----------|----------------|
| `HoverButton` | Button wrapper with hover/press state management |
| `BlackProgressStyle` | Custom progress bar style |
| `PreferenceKeys` | `ButtonFrameKey` for tracking button positions |
| `ViewExtensions` | `onPressGesture` modifier for press state tracking |

## Dropdown Panel Architecture

The dropdown logic mixes SwiftUI views with AppKit's `NSPanel`. The refactoring separates concerns:

1. **NSPanel Management** (stays in `ProviderListView`):
   - Creates, positions, and closes the panel
   - Manages `NSEvent` monitor for click-outside-to-close
   - Wraps SwiftUI content in `NSHostingView`

2. **Panel Content** (pure SwiftUI):
   - `ApiKeyDropdownPanel` and `ClaudeDropdownPanel` receive `onSelectApiKey` closures
   - They don't know about `NSPanel` - they're just content views
   - Testable and reusable independently

## State Management

**No changes to the state management architecture:**
- `AppState` remains the single source of truth
- Components read from `AppState.shared` directly
- Data flow: props in, events out via closures

## Testing Improvements

Extracting components enables better testing:

| Component | Testability |
|-----------|-------------|
| `ProviderIcon` | Snapshot test for each providerId |
| `QuotaProgressView` | Test loading/success/error states |
| `ClaudeCredentialCard` | Test all combinations (selected, loading, progress) |
| `HoverButton` | Verify hover/press state transitions |

## Migration Steps

1. Create directory structure
2. Extract shared components (`HoverButton`, `BlackProgressStyle`, `PreferenceKeys`)
3. Extract `ProviderIcon` and `ProviderButton`
4. Extract `ProgressViews` (`QuotaProgressView`)
5. Extract `ActiveKeySection`
6. Extract Claude components (`Card`, `Cost`, `Login`)
7. Extract dropdown panels
8. Simplify `ProviderListView` to coordinator role
9. Build and verify
