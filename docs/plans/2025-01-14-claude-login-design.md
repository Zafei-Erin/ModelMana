# Claude Login Design

## Overview

Add automated Claude login functionality to ModelMana using PTY (pseudo-terminal) to interact with the `claude` CLI, supporting both Subscription and Console login methods.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       UI Layer                              │
│  ProviderListView → ClaudeLoginState (phase/status)         │
└───────────────────┬─────────────────────────────────────────┘
                    │ calls
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ClaudeLoginService.runLogin(method:, onPhaseChange:)      │
└───────────────────┬─────────────────────────────────────────┘
                    │ uses
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                     PTY Runner Layer                        │
│  TTYCommandRunner.run(binary:, options:, callbacks)        │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. TTYCommandRunner (Services/)

Generic PTY runner, decoupled from Claude-specific logic.

**Key Features:**
- Creates pseudo-terminal using `openpty()`
- Non-blocking read with rolling buffer pattern matching
- Configurable stop conditions and auto-responses

**Options:**
```swift
struct Options {
    var rows: UInt16 = 50
    var cols: UInt16 = 160
    var timeout: TimeInterval = 120
    var extraArgs: [String] = []
    var stopOnSubstrings: [String] = []
    var sendOnSubstrings: [String: String] = [:]
    var settleAfterStop: TimeInterval = 0.25
}
```

### 2. ClaudeLoginService (Services/)

Encapsulates Claude login logic.

**Configuration:**
```swift
func runLogin(method: ClaudeLoginMethod, onPhaseChange: @escaping (ClaudeLoginPhase) -> Void) async throws
```

**PTY Options for Claude:**
- `extraArgs: ["/login"]`
- `stopOnSubstrings: ["Successfully logged in", "Login successful", "Logged in successfully"]`
- `sendOnSubstrings: ["Select login method:": "\(method.rawValue)\r"]`
- `settleAfterStop: 0.35`

## Data Flow

1. User clicks "Login with Subscription" or "Login with Console" button
2. `AppState.startClaudeLogin(method:)` sets phase to `.requesting`
3. `ClaudeLoginService` configures and calls `TTYCommandRunner.run()`
4. PTY runner:
   - Detects "Select login method:" → auto-sends "1\r" or "2\r"
   - Detects "https://" → callback to set phase `.waitingBrowser`
   - Detects success substring → stops and returns result
5. Service updates phase to `.success` or `.failed(...)`
6. UI displays status via `ClaudeLoginStatusView`

## File Structure

```
ModelMana/Services/
├── TTYCommandRunner.swift      # New - Generic PTY runner
└── ClaudeLoginService.swift    # New - Claude login service

ModelMana/Models/
└── ClaudeLoginState.swift      # Existing - State definitions

ModelMana/ViewModels/
└── AppState.swift              # Modify - Implement startClaudeLogin
```

## Error Handling

| Scenario          | Behavior                          |
|-------------------|-----------------------------------|
| CLI not found     | `.failed("Claude CLI not found")` |
| Timeout (120s)    | `.failed("Login timed out")`      |
| CLI error output  | `.failed(output message)          |
| Success detected  | `.success`                        |
