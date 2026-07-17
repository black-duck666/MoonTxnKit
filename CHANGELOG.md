# Changelog

## 0.4.0 - 2026-07-17

- Update executable package metadata and remove ambiguous empty-map warnings for
  MoonBit 0.10.4 strict checks.
- Add deterministic committed-state checkpoints through `Engine::snapshot` and
  `Engine::from_snapshot`; active transactions are excluded by design.
- Add snapshot recovery coverage and expand the reproducible predicate/WAL
  workload to 1k, 10k, and 100k keys.
- Add explicit OSC acceptance gates and documentation for strict toolchain
  compatibility and persistence adapter boundaries.

## 0.3.0 - 2026-07-06

- 新增稳定排序的事务快照前缀扫描。
- Serializable 模式新增谓词读跟踪与幻读冲突检测。
- 前缀扫描支持事务内新增、更新和删除覆盖。
- 保存点可完整回滚谓词读集合。
- 新增 10,000 键扫描、幻读拒绝与 WAL 恢复工作负载。
- 增加四后端 CI 矩阵和生成接口校验。

## 0.2.0 - 2026-07-03

- 增加 `AtomicPlan` 声明式业务条件与原子状态迁移。
- 增加任务领取、库存预占、幂等消费和受保护删除测试。
- 补充项目价值、抽象边界和真实工作流示例。

## 0.1.0 - 2026-06-30

- 实现确定性 MVCC 事务模型。
- 实现 Snapshot 与 Serializable 点读隔离语义。
- 实现保存点、逻辑 WAL、幂等恢复和版本压缩。
- 提供统计、校验、JSON 报告、测试和 CLI。
