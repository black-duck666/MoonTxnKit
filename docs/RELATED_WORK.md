# 社区查重与边界

## 查重结论

2026 年 6 月 30 日以 `MVCC`、`snapshot isolation`、`serializable transaction`、`write-ahead log`、`transactional key-value` 等关键词检查 Mooncakes 和公开 MoonBit 项目，没有发现定位为“通用确定性 MVCC 事务与逻辑恢复基础库”的同类包。

## 已有相关能力

- `moonbitlang/async` 提供异步任务重试与退避，解决执行失败后的重新调用，不维护多版本状态、事务快照或提交冲突。
- `Lampese/lomo` 的 Loro 文档实现包含 CRDT 文档事务，用于把协同编辑操作组织成变更；它服务于 CRDT 文档模型，不是通用键值 MVCC 引擎。
- 部分数据库、Git 和缓存项目内部具有日志、增量或状态管理代码，但没有向 MoonBit 生态提供本项目这组独立事务 API。

## MoonTxnKit 的位置

MoonTxnKit 不实现 SQL、索引、文件页或网络复制，而是把事务语义独立出来。它适合作为更大系统的内存协调层、确定性测试内核或持久化适配器的上游。

## 参考链接

- Mooncakes: <https://mooncakes.io/>
- MoonBit Async Retry: <https://mooncakes.io/docs/moonbitlang/async>
- Lomo/Loro 文档实现: <https://mooncakes.io/docs/Lampese/lomo>
