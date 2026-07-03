# 能力证据

| 能力 | 公开接口 | 回归测试 |
| --- | --- | --- |
| 声明式原子迁移 | `AtomicPlan`、`Engine::execute` | workflow, inventory, idempotency |
| 快照读取 | `begin`、`get`、`read_at` | repeatable snapshot |
| 写写冲突 | `commit` | concurrent writes |
| 写偏斜阻断 | `IsolationLevel::Serializable` | prevents write skew |
| 保存点 | `savepoint`、`rollback_to`、`release_savepoint` | savepoint rollback |
| WAL | `wal`、`WalRecord::is_valid` | checksum and operations |
| 恢复 | `recover`、`replay` | reconstructs values |
| 幂等重放 | `replay` | replaying same wal |
| 损坏拒绝 | `ReplayReport` | corrupted wal |
| 版本压缩 | `compact` | oldest active snapshot |
| 健康检查 | `stats`、`validate` | engine health |

验证命令：`moon fmt --check`、`moon check`、`moon test`、`moon test --target js`、`moon test --target wasm`、`moon test --target wasm-gc`、`moon run cmd/main`。

当前共有 23 项确定性测试。项目价值与适用对象见
[`VALUE_PROPOSITION.md`](VALUE_PROPOSITION.md)。
