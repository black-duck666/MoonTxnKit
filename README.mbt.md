# MoonTxnKit

MoonTxnKit 是面向 MoonBit 的确定性 MVCC 状态事务与恢复内核，适用于工作流、
规则引擎、模拟器、内存服务和测试替身。

## Serializable 前缀扫描

```moonbit nocheck
let engine = @moontxnkit.Engine::new()
let transaction = engine.begin(
  isolation=@moontxnkit.IsolationLevel::Serializable,
)

let rows = transaction.scan_prefix("task:queued:")
ignore(transaction.put("audit:scan", "\{rows.length()}"))

match transaction.commit() {
  @moontxnkit.CommitResult::CommittedAt(version) =>
    println("committed at \{version}")
  @moontxnkit.CommitResult::Rejected(conflict) =>
    println(conflict.to_json())
}
```

扫描结果来自事务快照，并叠加事务自己的新增、修改和删除，最终按键稳定排序。
Serializable 提交会检测前缀内的并发新增、更新和删除，返回结构化
`PredicateWrite` 冲突。

## 其他能力

- Snapshot Isolation 和点读 Serializable 校验；
- 声明式原子状态计划；
- 保存点和局部回滚；
- 逻辑 WAL、校验、幂等恢复；
- 历史读取、低水位压缩和 JSON 报告。

完整说明见仓库 [README.md](README.md) 与 `docs/`。
