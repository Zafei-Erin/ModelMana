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

## (待补充)
