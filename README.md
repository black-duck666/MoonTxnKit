# MoonTxnKit

面向 MoonBit 的确定性 MVCC 状态事务、谓词冲突检测与逻辑恢复内核。

MoonTxnKit 为工作流调度器、规则引擎、模拟器、内存服务和测试替身提供可复用的
“快照读取 + 原子变更 + 冲突证据 + WAL 恢复”能力，不绑定线程、磁盘或网络。

## 核心能力

- Snapshot Isolation 与 first-committer-wins 写冲突检测；
- Serializable 点读校验；
- 稳定排序的前缀谓词扫描与幻读检测；
- 事务内新增、更新、删除覆盖；
- 保存点、局部回滚和释放；
- 声明式 `AtomicPlan` 业务前置条件与整批状态变更；
- 带校验值的逻辑 WAL、连续版本检查和幂等恢复；
- 历史版本读取、低水位压缩、统计和内部一致性检查；
- Native、JavaScript、Wasm、Wasm-GC 后端中立。

## 防止扫描幻读

```moonbit
let transaction = engine.begin(
  isolation=@moontxnkit.IsolationLevel::Serializable,
)

let available = transaction.scan_prefix("inventory:available:")
// 业务根据同一快照中的完整前缀集合做决策。
ignore(transaction.put("reservation:42", "created"))

match transaction.commit() {
  @moontxnkit.CommitResult::CommittedAt(version) => ()
  @moontxnkit.CommitResult::Rejected(conflict) =>
    println(conflict.to_json())
}
```

提交前，Serializable 事务会检查快照之后是否有任何匹配前缀的键被新增、修改
或删除。若存在，返回 `PredicateWrite` 冲突，避免“扫描为空后两个事务都插入”
一类幻读与写偏斜。

## 验证

```bash
moon fmt --check
moon check --target all
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon run cmd/main --target js
moon run bench/main --target js
```

## 边界

当前值模型为 `String`，谓词模型为精确字符串前缀。项目不实现 SQL、任意比较
范围、磁盘刷盘、进程崩溃原子性或完整 SSI 依赖图；这些属于后续索引和适配层。

## License

Apache-2.0
