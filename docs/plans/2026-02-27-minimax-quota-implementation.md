# MiniMax Quota Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add MiniMax API quota tracking to display usage percentage and reset time for each MiniMax API key.

**Architecture:** Create `MiniMaxQuotaService` following the same pattern as `ZhipuQuotaService`. Update `MinimaxProvider.refreshQuota()` to call the new service. Store results in `quotas[apiKeyId]` using existing `QuotaState`/`QuotaItem` models.

**Tech Stack:** Swift 5.0, URLSession, Foundation JSON parsing

---

## Task 1: Create MiniMaxQuotaService.swift

**Files:**
- Create: `ModelMana/Services/MiniMax/MiniMaxQuotaService.swift`

**Step 1: Create the MiniMax Services directory (if not exists)**

```bash
mkdir -p ModelMana/Services/MiniMax
```

**Step 2: Create MiniMaxQuotaService.swift**

Create the file at `ModelMana/Services/MiniMax/MiniMaxQuotaService.swift`:

```swift
//
//  MiniMaxQuotaService.swift
//  ModelMana
//
//  MiniMax API 配额查询服务
//

import Foundation

struct MiniMaxQuotaService {
    private static let baseURL = "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains"

    /// 查询 API Key 的配额使用情况
    /// - Parameter apiKey: MiniMax API Key
    /// - Returns: Result containing an array of QuotaItems or Error
    static func fetchQuota(apiKey: String) async -> Result<[QuotaItem], Error> {
        guard let url = URL(string: baseURL) else {
            return .failure(QuotaError.parseError("Invalid URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("CodexBar", forHTTPHeaderField: "MM-API-Source")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return .failure(QuotaError.httpError(httpResponse.statusCode))
                }
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let baseResp = json["baseResp"] as? [String: Any],
                  let statusCode = baseResp["status_code"] as? Int,
                  statusCode == 0 else {
                return .failure(QuotaError.parseError("API returned error"))
            }

            guard let modelRemains = json["modelRemains"] as? [[String: Any]],
                  let firstModel = modelRemains.first else {
                return .failure(QuotaError.parseError("No quota data available"))
            }

            guard let totalCount = firstModel["currentIntervalTotalCount"] as? Double,
                  let usageCount = firstModel["currentIntervalUsageCount"] as? Double,
                  let endTime = firstModel["endTime"] as? TimeInterval else {
                return .failure(QuotaError.parseError("Missing quota fields"))
            }

            // Calculate percentage: (used / total) * 100
            let percentage = totalCount > 0 ? (usageCount / totalCount) * 100 : 0

            let item = QuotaItem(
                title: "Session",
                status: .success(percentage: percentage, nextResetTime: endTime)
            )

            return .success([item])

        } catch {
            return .failure(error)
        }
    }
}
```

**Step 3: Add file to Xcode project**

In Xcode:
1. Right-click on `Services` group
2. Select "New Group" → name it `MiniMax`
3. Right-click on `MiniMax` group → "Add Files to ModelMana..."
4. Select `MiniMaxQuotaService.swift`
5. Ensure "Copy items if needed" is unchecked (file already in place)
6. Ensure target ModelMana is checked

**Step 4: Run build to verify it compiles**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ModelMana/Services/MiniMax/MiniMaxQuotaService.swift
git commit -m "feat: add MiniMaxQuotaService"
```

---

## Task 2: Update MinimaxProvider to Use MiniMaxQuotaService

**Files:**
- Modify: `ModelMana/Providers/Minimax/MinimaxProvider.swift`

**Step 1: Replace refreshQuota implementation**

Find this code in `MinimaxProvider.swift` (lines 63-68):

```swift
private func refreshQuota(for apiKey: ApiKeyConfig) async {
    quotas[apiKey.id] = .loading

    // TODO: Implement Minimax quota API
    // For now, mark as error since API is not yet implemented
    quotas[apiKey.id] = .loaded([QuotaItem(title: "Session", status: .error("Not implemented"))])
}
```

Replace with:

```swift
private func refreshQuota(for apiKey: ApiKeyConfig) async {
    quotas[apiKey.id] = .loading

    let result = await MiniMaxQuotaService.fetchQuota(apiKey: apiKey.key)

    switch result {
    case .success(let items):
        if let percentage = items.first?.percentage {
            Logger.log("Minimax", "Quota: \(Int(percentage ?? 0))%")
        }
        quotas[apiKey.id] = .loaded(items)
    case .failure(let error):
        Logger.error("Minimax", error.localizedDescription)
        quotas[apiKey.id] = .loaded([
            QuotaItem(title: "Session", status: .error(error.localizedDescription))
        ])
    }
}
```

**Step 2: Add logging support to refreshUsage()**

Find this code in `MinimaxProvider.swift` (lines 33-43):

```swift
func refreshUsage() async {
    // Minimax uses same quota pattern as Zhipu
    // TODO: Implement Minimax-specific quota API when available
    await withTaskGroup(of: Void.self) { group in
        for apiKey in config.apiKeys {
            group.addTask {
                await self.refreshQuota(for: apiKey)
            }
        }
    }
}
```

Replace with:

```swift
func refreshUsage() async {
    if !config.apiKeys.isEmpty {
        Logger.log("Minimax", "Refreshing...")
    }
    await withTaskGroup(of: Void.self) { group in
        for apiKey in config.apiKeys {
            group.addTask {
                await self.refreshQuota(for: apiKey)
            }
        }
    }
}
```

**Step 3: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ModelMana/Providers/Minimax/MinimaxProvider.swift
git commit -m "feat: implement MiniMax quota fetching"
```

---

## Task 3: Verify Logger Support

**Files:**
- Check: `ModelMana/Services/Logger.swift` (or equivalent)

**Step 1: Check if Logger exists**

```bash
grep -r "struct Logger\|class Logger" ModelMana/
```

Expected: Should find Logger implementation

If Logger exists, verify it has `log` and `error` static methods. If not, the code will need to use print statements instead.

**Step 2: (If Logger doesn't exist) Use print statements instead**

If Logger doesn't exist, modify `MinimaxProvider.swift` refreshUsage and refreshQuota to use `print` instead of `Logger.log` and `Logger.error`:

```swift
// In refreshUsage():
if !config.apiKeys.isEmpty {
    print("[Minimax] Refreshing...")
}

// In refreshQuota(), success case:
if let percentage = items.first?.percentage {
    print("[Minimax] Quota: \(Int(percentage ?? 0))%")
}

// In refreshQuota(), error case:
print("[Minimax] Error: \(error.localizedDescription)")
```

---

## Task 4: Final Build and Test

**Step 1: Full build**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 2: Manual testing checklist**

- [ ] Build succeeds without errors
- [ ] Add a MiniMax API key in Settings
- [ ] MiniMax key appears in dropdown
- [ ] Quota percentage displays (or error if API key is invalid)
- [ ] Reset time displays correctly
- [ ] Auto-refresh works (every 10 minutes)

**Step 3: (Optional) Test with real API key**

If you have a valid MiniMax API key, you can test the actual API:

1. Add the API key in Settings
2. Check Console logs for quota response
3. Verify percentage displays correctly

**Step 4: Final commit**

```bash
git add .
git commit -m "docs: complete MiniMax quota implementation"
```

---

## Appendix: API Response Example

For reference, the MiniMax API returns:

```json
{
  "baseResp": {
    "status_code": 0
  },
  "modelRemains": [
    {
      "currentIntervalTotalCount": 1000,
      "currentIntervalUsageCount": 250,
      "endTime": 1740451200000,
      "modelName": "model-name"
    }
  ]
}
```

Where:
- `currentIntervalTotalCount`: Total quota for the interval
- `currentIntervalUsageCount`: Already used amount
- `endTime`: Reset time in milliseconds since epoch
- `percentage = (usageCount / totalCount) * 100`
