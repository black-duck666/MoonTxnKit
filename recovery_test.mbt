///|
fn seeded_engine() -> @moontxnkit.Engine {
  let engine = @moontxnkit.Engine::new()
  let seed = engine.begin()
  ignore(seed.put("doctor-a", "on"))
  ignore(seed.put("doctor-b", "on"))
  ignore(seed.commit())
  engine
}

///|
test "serializable validation prevents write skew" {
  let engine = seeded_engine()
  let first = engine.begin(isolation=@moontxnkit.IsolationLevel::Serializable)
  let second = engine.begin(isolation=@moontxnkit.IsolationLevel::Serializable)
  assert_true(first.get("doctor-b") == Some("on"))
  assert_true(second.get("doctor-a") == Some("on"))
  ignore(first.put("doctor-a", "off"))
  ignore(second.put("doctor-b", "off"))
  assert_true(first.commit() == @moontxnkit.CommitResult::CommittedAt(2))
  match second.commit() {
    @moontxnkit.CommitResult::Rejected(conflict) =>
      assert_true(conflict.kind == @moontxnkit.ConflictKind::ReadWrite)
    _ => fail("serializable transaction should reject stale read set")
  }
  assert_true(engine.get("doctor-a") == Some("off"))
  assert_true(engine.get("doctor-b") == Some("on"))
}

///|
test "snapshot isolation documents write skew tradeoff" {
  let engine = seeded_engine()
  let first = engine.begin()
  let second = engine.begin()
  ignore(first.get("doctor-b"))
  ignore(second.get("doctor-a"))
  ignore(first.put("doctor-a", "off"))
  ignore(second.put("doctor-b", "off"))
  assert_true(first.commit() == @moontxnkit.CommitResult::CommittedAt(2))
  assert_true(second.commit() == @moontxnkit.CommitResult::CommittedAt(3))
  assert_true(engine.get("doctor-a") == Some("off"))
  assert_true(engine.get("doctor-b") == Some("off"))
}

///|
test "savepoint rolls back only later reads and writes" {
  let engine = @moontxnkit.Engine::new()
  let txn = engine.begin()
  ignore(txn.put("a", "before"))
  assert_true(txn.savepoint("step-1"))
  ignore(txn.put("a", "after"))
  ignore(txn.put("b", "temporary"))
  assert_eq(txn.pending_writes(), 2)
  assert_true(txn.rollback_to("step-1"))
  assert_eq(txn.pending_writes(), 1)
  assert_eq(txn.savepoint_count(), 1)
  assert_true(txn.release_savepoint("step-1"))
  assert_true(txn.commit() == @moontxnkit.CommitResult::CommittedAt(1))
  assert_true(engine.get("a") == Some("before"))
  assert_true(engine.get("b") is None)
}

///|
test "wal record carries valid checksum and operations" {
  let engine = @moontxnkit.Engine::new()
  let txn = engine.begin()
  ignore(txn.put("account", "100"))
  ignore(txn.delete("legacy"))
  ignore(txn.commit())
  let records = engine.wal()
  assert_eq(records.length(), 1)
  assert_true(records[0].is_valid())
  assert_eq(records[0].operations.length(), 2)
  assert_true(records[0].to_json().contains("\"commit_version\":1"))
}

///|
test "recovery reconstructs values and history" {
  let engine = @moontxnkit.Engine::new()
  let first = engine.begin()
  ignore(first.put("value", "v1"))
  ignore(first.commit())
  let second = engine.begin()
  ignore(second.put("value", "v2"))
  ignore(second.put("other", "ready"))
  ignore(second.commit())
  let (recovered, report) = @moontxnkit.Engine::recover(engine.wal())
  assert_true(report.valid)
  assert_eq(report.applied_records, 2)
  assert_eq(recovered.version(), 2)
  assert_true(recovered.get("value") == Some("v2"))
  assert_true(recovered.read_at("value", 1) == Some("v1"))
  assert_true(recovered.get("other") == Some("ready"))
}

///|
test "replaying same wal is idempotent" {
  let source = @moontxnkit.Engine::new()
  let txn = source.begin()
  ignore(txn.put("key", "value"))
  ignore(txn.commit())
  let records = source.wal()
  let (recovered, first_report) = @moontxnkit.Engine::recover(records)
  assert_eq(first_report.applied_records, 1)
  let second_report = recovered.replay(records)
  assert_true(second_report.valid)
  assert_eq(second_report.applied_records, 0)
  assert_eq(second_report.skipped_records, 1)
  assert_eq(recovered.stats().versions, 1)
}

///|
test "replay rejects corrupted wal before applying it" {
  let operation = @moontxnkit.WriteIntent::put("key", "value")
  let valid = @moontxnkit.WalRecord::new(1, 0, 1, [operation])
  let corrupt = @moontxnkit.WalRecord::{
    transaction_id: valid.transaction_id,
    snapshot_version: valid.snapshot_version,
    commit_version: valid.commit_version,
    operations: valid.operations,
    checksum: valid.checksum + 1,
  }
  let engine = @moontxnkit.Engine::new()
  let report = engine.replay([corrupt])
  assert_false(report.valid)
  assert_eq(report.applied_records, 0)
  assert_eq(engine.version(), 0)
  assert_true(engine.get("key") is None)
}

///|
test "compaction respects oldest active snapshot" {
  let engine = @moontxnkit.Engine::new()
  let first = engine.begin()
  ignore(first.put("key", "v1"))
  ignore(first.commit())
  let reader = engine.begin()
  for value in ["v2", "v3"] {
    let writer = engine.begin()
    ignore(writer.put("key", value))
    ignore(writer.commit())
  }
  let while_active = engine.compact()
  assert_eq(while_active.low_watermark, 1)
  assert_true(reader.get("key") == Some("v1"))
  ignore(reader.abort())
  let after_abort = engine.compact()
  assert_eq(after_abort.low_watermark, 3)
  assert_eq(after_abort.removed_versions, 2)
  assert_eq(engine.stats().versions, 1)
  assert_true(engine.get("key") == Some("v3"))
}

///|
test "stats and validation summarize engine health" {
  let engine = seeded_engine()
  let stats = engine.stats()
  assert_eq(stats.current_version, 1)
  assert_eq(stats.keys, 2)
  assert_eq(stats.versions, 2)
  assert_eq(stats.committed_transactions, 1)
  assert_eq(stats.wal_records, 1)
  assert_eq(engine.validate().length(), 0)
  assert_true(stats.to_json().contains("\"keys\":2"))
}
