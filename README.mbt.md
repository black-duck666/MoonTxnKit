# MoonTxnKit

MoonTxnKit 是面向 MoonBit 的确定性状态事务与恢复内核。它为工作流调度器、内存服务、模拟器、规则引擎、测试替身和嵌入式工具提供声明式原子状态计划、快照读取、乐观提交、可串行化读集校验、保存点、逻辑 WAL、幂等重放和安全版本压缩。

项目不是 SQL 数据库，也不绑定磁盘、线程或网络。核心只维护逻辑版本和可序列化记录，调用方可以自行选择文件、浏览器存储、对象存储或数据库作为 WAL 持久化层。

## 核心能力

- 每个事务固定一个逻辑快照，重复读取不会被后续提交改变；
- Snapshot Isolation 使用 first-committer-wins 检测写写冲突；
- Serializable 模式额外验证读集，阻止常见写偏斜；
- 事务内支持保存点、局部回滚和释放；
- 每个写事务产生带校验值的逻辑 WAL；
- 恢复前验证校验值和提交版本连续性，支持重复日志幂等跳过；
- `read_at` 提供历史版本读取；
- 以最老活跃快照为低水位压缩历史版本；
- 提供统计、内部一致性校验和 JSON 报告；
- 核心无系统时钟、随机数和平台 IO，便于跨后端确定性测试。

## 快速示例

```moonbit nocheck
let engine = @moontxnkit.Engine::new()

let plan = @moontxnkit.AtomicPlan::new("claim-task")
  .expect("task:42:state", "queued")
  .expect_missing("task:42:owner")
  .put("task:42:state", "running")
  .put("task:42:owner", "worker-7")
let result = engine.execute(plan)

println(result.to_json())
println(engine.stats().to_json())

let (recovered, report) = @moontxnkit.Engine::recover(engine.wal())
println(report.to_json())
println(recovered.history_json("account-a"))
```

## 验证

```bash
moon fmt --check
moon check
moon test
moon run cmd/main
```

当前共有 23 项确定性测试。CLI 展示银行转账、长快照读取、并发写拒绝、历史版本、WAL 重放和低水位压缩；AtomicPlan 测试覆盖任务领取、库存预占、幂等消费和受保护删除。

## 设计边界

当前版本以 `String` 作为键和值，聚焦事务语义而不是存储格式。Serializable 模式验证点读集合，可以阻止读写依赖导致的写偏斜；项目尚未提供范围扫描，因此也不声称处理谓词读产生的幻读。逻辑 WAL 由库生成和校验，持久化、刷盘顺序及进程崩溃原子性由外层适配器负责。

## 仓库

- GitHub: <https://github.com/black-duck666/MoonTxnKit>
- GitLink: <https://www.gitlink.org.cn/black-duck/MoonTxnKit>
