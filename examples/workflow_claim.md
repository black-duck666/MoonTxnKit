# 工作流任务领取

工作流系统常见的竞争是：多个 worker 同时看到一项 queued 任务，都尝试成为
owner。直接执行两次 Map 写入会留下竞态窗口，先写 state 再写 owner 还可能
产生半完成状态。

MoonTxnKit 用一个 `AtomicPlan` 表达完整迁移：

```moonbit
let claim = @moontxnkit.AtomicPlan::new("claim-task")
  .expect("task:42:state", "queued")
  .expect_missing("task:42:owner")
  .put("task:42:state", "running")
  .put("task:42:owner", "worker-7")

let result = engine.execute(claim)
```

执行过程具有以下保证：

1. state 与 owner 在同一快照读取；
2. 两个条件必须同时成立；
3. state 与 owner 使用同一提交版本写入；
4. 条件失败不会推进版本，也不会产生部分写；
5. 提交生成逻辑 WAL，可由外层持久化和恢复；
6. 结果可以稳定输出为 JSON，供日志、CI 和调试器使用。

相同模式可以用于幂等事件消费、订单状态机、资源租约和策略配置切换。
