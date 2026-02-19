# Modular Provider Architecture Design

**Date:** 2025-01-25
**Status:** Approved
**Author:** Claude Code

## Overview

Refactor ModelMana from a monolithic `AppState` to a protocol-based provider architecture. Each provider (Claude, Zhipu, Minimax) becomes a self-contained module that owns its state, usage data, and UI.

## Problem Statement

Current architecture has several issues:

1. **AppState is overloaded** - Handles configuration, quotas, login states, timers (~120 lines)
2. **Provider logic scattered** - `AppState+Claude.swift`, `AppState+Zhipu.swift` extensions
3. **Views contain business logic** - ProviderListView.swift (355 lines) with `if provider == .claude` checks
4. **Adding new providers requires** - Editing AppState, creating extensions, modifying multiple views

## Proposed Solution

Protocol-based provider architecture where each provider:
- Owns its state (`@Observable` class)
- Implements `refreshUsage()` for its data needs
- Provides its own dropdown panel view
- Can reuse shared UI components

## Architecture

### File Structure

```
ModelMana/
├── App/
│   └── ModelManaApp.swift
├── Core/
│   ├── AppState.swift              # Simplified config holder
│   └── AppConfiguration.swift      # Existing (unchanged)
├── Providers/
│   ├── ProviderProtocol.swift      # Provider protocol
│   ├── ProviderRegistry.swift      # Singleton + timer
│   ├── Claude/
│   │   ├── ClaudeProvider.swift    # @Observable class
│   │   └── ClaudeDropdownPanel.swift
│   ├── Zhipu/
│   │   ├── ZhipuProvider.swift
│   │   └── ZhipuDropdownPanel.swift
│   └── Minimax/
│       ├── MinimaxProvider.swift
│       └── MinimaxDropdownPanel.swift
├── Services/                       # Keep existing services
├── Models/                         # Keep existing models
└── Views/
    ├── Settings/
    ├── ProviderList/
    └── Shared/                     # Reusable components
        ├── ApiKeyCard.swift
        ├── QuotaProgressBar.swift
        └── ProviderIcon.swift
```

### Provider Protocol

```swift
@MainActor
protocol Provider: Observable, Identifiable {
    var id: String { get }
    var name: String { get }
    var config: ProviderConfig { get }

    func refreshUsage() async
    func makeDropdownPanel() -> any View
    func makeSettingsView() -> (any View)?
}
```

**Key decision:** Protocol does NOT prescribe usage data structure. Each provider defines its own state properties because usage patterns differ fundamentally:
- Claude: subscription + console + API keys (3 types)
- Zhipu: per-key quotas (dictionary)
- Minimax: similar to Zhipu

### Provider Registry

```swift
@Observable
class ProviderRegistry {
    static let shared = ProviderRegistry()

    var configuration: AppConfiguration  // Source of truth

    var claude: ClaudeProvider!
    var zhipu: ZhipuProvider!
    var minimax: MinimaxProvider!

    var allProviders: [any Provider]
    var selectedProvider: (any Provider)?

    private var refreshTimer: Timer?

    func refreshAll() async
}
```

**Responsibilities:**
- Hold provider instances
- Own auto-refresh timer (10 min interval)
- Sync configuration changes to disk
- Provide access to currently selected provider

### Concrete Provider Example

```swift
@Observable
class ZhipuProvider: Provider {
    let id = "zhipu"
    let name = "Zhipu"
    let config: ProviderConfig

    var quotas: [String: ApiKeyQuota] = [:]

    init(config: ProviderConfig) {
        self.config = config
        for key in config.apiKeys {
            quotas[key.id] = ApiKeyQuota(status: .loading)
        }
    }

    func refreshUsage() async {
        await withTaskGroup(of: Void.self) { group in
            for apiKey in config.apiKeys {
                group.addTask {
                    await self.refreshQuota(for: apiKey)
                }
            }
        }
    }

    func makeDropdownPanel() -> any View {
        ZhipuDropdownPanel(provider: self)
    }
}
```

### Shared UI Components

```swift
// Reusable by any provider
struct ApiKeyCard: View {
    let apiKey: ApiKeyConfig
    let quota: ApiKeyQuota?
    let isSelected: Bool
    let onSelect: () -> Void
}

struct QuotaProgressBar: View {
    let quota: ApiKeyQuota
}

struct ProviderIcon: View {
    let provider: any Provider
}
```

### View Access Pattern

Views access providers via singleton:

```swift
struct ProviderListView: View {
    var body: some View {
        if let current = ProviderRegistry.shared.selectedProvider {
            AnyView(current.makeDropdownPanel())
        }
    }
}
```

**Decision:** Singleton access (not Environment) for simplicity.

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ProviderRegistry.shared                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   claude    │  │    zhipu    │  │      minimax        │  │
│  │ @Observable │  │ @Observable │  │    @Observable      │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                         │                                   │
│                 configuration: AppConfiguration             │
│                 (synced to ~/.modelmana/config.json)        │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ refreshAll() every 10 min
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│     ProviderDropdownPanels  +  Shared UI Components          │
└─────────────────────────────────────────────────────────────┘
```

## Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider scope | Full Provider (data + UI) | YAGNI, simpler mental model |
| State ownership | Provider owns (@Observable) | Fine-grained re-renders |
| Config storage | AppConfiguration is source | No duplication, simpler |
| Timer owner | ProviderRegistry | Single coordinator |
| UI components | Views/Shared/ | Reuse without forcing patterns |
| View access | Singleton | Simpler than Environment |

## Benefits

1. **Adding new provider** = One new folder implementing protocol
2. **Each provider is testable** in isolation
3. **Views are simpler** - just call `provider.makeDropdownPanel()`
4. **No more `if provider == .claude`** scattered through views
5. **AppState becomes minimal** - just holds config, delegates to Registry

## Migration Plan

1. Create `Providers/` directory structure
2. Implement `ProviderProtocol.swift`
3. Implement `ProviderRegistry.swift` (with empty providers)
4. Implement each provider module one by one
5. Refactor `AppState` to use `ProviderRegistry`
6. Refactor views to use provider abstraction
7. Remove `AppState+Claude.swift`, `AppState+Zhipu.swift`
8. Test thoroughly

## Implementation Status

- [ ] Create Providers directory structure
- [ ] Implement ProviderProtocol.swift
- [ ] Implement ProviderRegistry.swift
- [ ] Implement ClaudeProvider module
- [ ] Implement ZhipuProvider module
- [ ] Implement MinimaxProvider module
- [ ] Refactor AppState
- [ ] Refactor Views
- [ ] Remove old extensions
