# 社区差异与边界

MoonBit 生态已有异步重试、CRDT 文档、数据库绑定和各类存储组件。它们分别
解决执行重试、协同合并或外部数据库访问，不等同于独立的确定性 MVCC 内核。

MoonTxnKit 的组合边界是：

- 纯 MoonBit 逻辑版本与快照读取；
- Snapshot/Serializable 冲突证据；
- 前缀谓词幻读检测；
- 声明式原子状态计划；
- 可校验、可重放的逻辑 WAL；
- 与平台 IO 解耦的恢复和压缩。

截至 2026-07-06，以 MVCC、snapshot isolation、predicate conflict、
serializable transaction 和 WAL 检索 Mooncakes，未发现覆盖上述完整范围的
MoonBit 通用包。

项目不与成熟数据库竞争 SQL、索引、磁盘页和复制协议，而作为更大系统的内存
协调层、确定性测试内核或持久化适配器上游。
