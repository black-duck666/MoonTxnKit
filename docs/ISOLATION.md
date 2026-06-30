# 隔离级别

## Snapshot

事务开始时记录 `snapshot_version`。读取只看不超过该版本的最新提交值，并优先返回自己的写。提交采用 first-committer-wins：如果任一写键在快照后发生变化，整个事务被拒绝。

该模式避免脏读、不可重复读和丢失更新，但不同写键之间仍可能出现写偏斜。测试 `snapshot isolation documents write skew tradeoff` 明确记录了这一边界。

## Serializable

Serializable 在 Snapshot 的写集校验之外，对事务实际读取的每个键执行提交时验证。如果某个读键在快照后被修改，事务以 `ReadWrite` 冲突拒绝。

这可以阻止典型的“A 读取 B 后写 A，B 读取 A 后写 B”写偏斜。当前引擎只提供点读，没有范围扫描，因此该模式不宣称处理谓词冲突和幻读。

## 冲突是正常结果

冲突通过 `CommitResult::Rejected(TxnConflict)` 返回，而不是异常。调用方可以检查冲突类型、键、快照版本和当前版本，再决定重试、提示用户或记录审计事件。
