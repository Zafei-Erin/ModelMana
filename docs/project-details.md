# ModelMana 项目细节文档

记录项目实现中的各种技术细节和设计决策。

---

## Provider 用量查询实现

### Claude
- **OAuth 订阅**: `ClaudeOAuthUsageFetcher` 调用 `/api/oauth/usage`，返回 5 小时/7 天使用率
- **Console 登录**: `ClaudeConsoleCookieClient` 获取 Cookie，`ClaudeConsoleCostService` 调用 Console metrics API
- **API Key**: 未实现

### Zhipu
- `ZhipuQuotaService` 调用 `/api/monitor/usage/quota/limit`，查找 `type=TOKENS_LIMIT` 且 `unit=3` 的配额数据

### Minimax
- 待接入实际 API

### 调用入口
- `ProviderRegistry.refreshAll()` 并行刷新所有 Provider
- **刷新策略**: 所有方式（subscription、console、api keys）无条件刷新，每 10 分钟一次

---

## Claude Keychain 凭证管理

### `writeKeychainAuthSettings()`

**用途**：支持 Claude Subscription/Console 登录模式。

**原理**：
- Claude CLI 会把 Subscription/Console 凭证存储在 macOS Keychain 中
- 如果 `~/.claude/settings.json` 中有 `ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_BASE_URL`，CLI 会优先使用这些环境变量
- 通过从 env 中**移除**这两个 key，让 CLI 降级使用 Keychain 凭证

**实现位置**：`SettingsFileService.writeKeychainAuthSettings()`

```swift
// 完全移除 key（比设置为空字符串更干净）
var env = existing["env"] as? [String: Any] ?? [:]
env.removeValue(forKey: "ANTHROPIC_AUTH_TOKEN")
env.removeValue(forKey: "ANTHROPIC_BASE_URL")
```

### `deleteClaudeKeychainEntry()`

**用途**：当用户从 Claude Subscription/Console 切换到其他 provider（如 Zhipu、Minimax）时，清理 Claude CLI 的 Keychain 凭证。

**问题场景**：
1. 用户用 Claude Subscription 登录 → 凭证存在 Keychain
2. 切换到 Zhipu provider → settings.json 写入 Zhipu 的 key
3. 如果不清理 Keychain → Claude CLI 可能仍使用 Keychain 中的旧凭证

**实现方式**：
```swift
// 调用 claude /logout 让 Claude CLI 自己清理凭证
try await ClaudeLoginService.shared.startLogout()
// 然后恢复 hasCompletedOnboarding 标志
try? configureClaudeJson()
```

**调用位置**：`ProviderListView.selectApiKey()` 中，当切换 provider 时触发

```swift
// 如果当前是 Claude subscription/console，且切换到非 claude provider
if case .subscription = currentCredential {
    if providerConfig.id != "claude" {
        SettingsFileService.deleteClaudeKeychainEntry()
        AppState.shared.selectedClaudeCredential = nil
    }
}
```

---

## (待补充)
