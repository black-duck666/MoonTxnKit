# MoonTxnKit

面向 MoonBit 的确定性状态事务与恢复内核。

MoonTxnKit 让规则引擎、工作流调度器、模拟器、内存服务和测试替身获得一套
可复用的“条件检查 + 原子变更 + 冲突证据 + 日志恢复”能力，而不必各自实现
版本号、临时副本、回滚和重放。

它不是 SQL 数据库，也不是 transactions 教学封装。项目把事务语义从磁盘、
线程、网络和具体业务模型中分离出来，作为可以嵌入更大系统的纯 MoonBit
状态提交内核。

## 典型场景

| 场景 | 需要保证的状态规则 |
| --- | --- |
| 工作流任务领取 | 任务仍为 queued 且尚无 owner，才能原子写入 running 与 owner |
| 库存预占 | 库存版本与订单状态同时满足条件，库存和订单才一起变更 |
| 幂等事件消费 | 处理标记不存在时才执行整批状态写入 |
| 规则与策略引擎 | 多个事实必须来自同一快照，规则结论才能提交 |
| 模拟器与测试替身 | 相同命令序列必须得到相同冲突、版本和恢复结果 |
| 离线状态工具 | 先生成逻辑 WAL，再由浏览器、文件或对象存储适配器持久化 |

## 声明式原子计划

上层不必手写事务控制流程。`AtomicPlan` 把业务不变量和整批状态变更组织成
一个可审计对象：

```moonbit
let plan = @moontxnkit.AtomicPlan::new("claim-task")
  .expect("task:42:state", "queued")
  .expect_missing("task:42:owner")
  .put("task:42:state", "running")
  .put("task:42:owner", "worker-7")

match engine.execute(plan) {
  @moontxnkit.PlanResult::AppliedAt(version) =>
    println("claimed at version \{version}")
  @moontxnkit.PlanResult::ConditionFailed(failure) =>
    println(failure.to_json())
  @moontxnkit.PlanResult::CommitRejected(conflict) =>
    println(conflict.to_json())
}
```

计划先在同一快照中检查全部条件，再原子应用写集合。任一条件不满足时，版本
不会推进，也不会留下部分写入。Serializable 模式还会在提交时验证读集，防止
检查后相关状态已被其他事务改变。

## 底层能力

- Snapshot Isolation 与 first-committer-wins 写冲突检测；
- Serializable 读集校验和结构化冲突结果；
- 保存点、局部回滚、删除墓碑和历史版本读取；
- 带校验值的逻辑 WAL、版本连续性验证和幂等重放；
- 最老活跃快照低水位压缩；
- 统计、不变量校验和稳定 JSON 证据；
- 不读取系统时钟、不使用随机数、不绑定平台 IO；
- Native、JavaScript、Wasm、Wasm-GC 后端保持确定行为。

## 为什么这个抽象成立

事务内核只负责四件事：读哪个逻辑快照、哪些条件必须仍成立、哪些状态必须
一起提交、如何记录和恢复提交结果。业务对象编码、WAL 保存位置、并发执行器
和网络协议都留给上层。这条边界足够小，可以被多个领域复用；同时又覆盖原子
状态迁移真正需要的隔离、冲突与恢复语义。

## 验证

```text
moon fmt --check
moon check
moon test
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon run cmd/main
```

当前有 23 项确定性测试，覆盖事务语义、AtomicPlan、WAL、恢复、压缩和多种
失败边界。

## 文档

- [架构说明](docs/ARCHITECTURE.md)
- [项目价值与抽象边界](docs/VALUE_PROPOSITION.md)
- [隔离语义](docs/ISOLATION.md)
- [恢复语义](docs/RECOVERY.md)
- [社区查重](docs/RELATED_WORK.md)
- [能力证据](docs/EVIDENCE.md)
- [工作流任务领取示例](examples/workflow_claim.md)
- [银行转账示例](examples/bank_transfer.md)

## 仓库

- GitHub: <https://github.com/black-duck666/MoonTxnKit>
- GitLink: <https://www.gitlink.org.cn/black-duck/MoonTxnKit>

## License

Apache-2.0
