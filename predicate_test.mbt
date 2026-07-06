///|
fn seed_prefix_engine() -> @moontxnkit.Engine {
  let engine = @moontxnkit.Engine::new()
  let seed = engine.begin()
  ignore(seed.put("task:queued:2", "beta"))
  ignore(seed.put("task:queued:1", "alpha"))
  ignore(seed.put("task:done:9", "done"))
  ignore(seed.commit())
  engine
}

///|
test "prefix scan is sorted and isolated by namespace" {
  let engine = seed_prefix_engine()
  let transaction = engine.begin()
  let rows = transaction.scan_prefix("task:queued:")
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].key, "task:queued:1")
  assert_eq(rows[0].value, "alpha")
  assert_eq(rows[1].key, "task:queued:2")
}

///|
test "prefix scan overlays own inserts updates and deletes" {
  let engine = seed_prefix_engine()
  let transaction = engine.begin()
  ignore(transaction.put("task:queued:3", "gamma"))
  ignore(transaction.put("task:queued:2", "updated"))
  ignore(transaction.delete("task:queued:1"))
  let rows = transaction.scan_prefix("task:queued:")
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].key, "task:queued:2")
  assert_eq(rows[0].value, "updated")
  assert_eq(rows[1].key, "task:queued:3")
}

///|
test "serializable prefix read rejects phantom insert" {
  let engine = @moontxnkit.Engine::new()
  let reader = engine.begin(isolation=@moontxnkit.IsolationLevel::Serializable)
  assert_eq(reader.scan_prefix("slot:").length(), 0)
  let writer = engine.begin()
  ignore(writer.put("slot:a", "occupied"))
  assert_true(writer.commit() == @moontxnkit.CommitResult::CommittedAt(1))
  ignore(reader.put("audit", "saw-empty"))
  match reader.commit() {
    @moontxnkit.CommitResult::Rejected(conflict) => {
      assert_true(conflict.kind == @moontxnkit.ConflictKind::PredicateWrite)
      assert_eq(conflict.key, "slot:a")
      assert_eq(conflict.current_version, 1)
    }
    _ => fail("serializable prefix read must reject a phantom")
  }
}

///|
test "serializable prefix read rejects update and delete" {
  let engine = seed_prefix_engine()
  let reader = engine.begin(isolation=@moontxnkit.IsolationLevel::Serializable)
  assert_eq(reader.scan_prefix("task:queued:").length(), 2)
  let writer = engine.begin()
  ignore(writer.delete("task:queued:2"))
  ignore(writer.commit())
  match reader.commit() {
    @moontxnkit.CommitResult::Rejected(conflict) =>
      assert_true(conflict.kind == @moontxnkit.ConflictKind::PredicateWrite)
    _ => fail("serializable prefix read must reject a changed member")
  }
}

///|
test "snapshot prefix read keeps snapshot isolation semantics" {
  let engine = @moontxnkit.Engine::new()
  let reader = engine.begin()
  assert_eq(reader.scan_prefix("slot:").length(), 0)
  let writer = engine.begin()
  ignore(writer.put("slot:a", "occupied"))
  ignore(writer.commit())
  ignore(reader.put("audit", "snapshot-empty"))
  assert_true(reader.commit() == @moontxnkit.CommitResult::CommittedAt(2))
}

///|
test "rollback restores prefix observation savepoint" {
  let engine = @moontxnkit.Engine::new()
  let transaction = engine.begin(
    isolation=@moontxnkit.IsolationLevel::Serializable,
  )
  assert_true(transaction.savepoint("before-scan"))
  ignore(transaction.scan_prefix("slot:"))
  assert_true(transaction.rollback_to("before-scan"))
  let writer = engine.begin()
  ignore(writer.put("slot:a", "occupied"))
  ignore(writer.commit())
  ignore(transaction.put("audit", "scan-rolled-back"))
  assert_true(transaction.commit() == @moontxnkit.CommitResult::CommittedAt(2))
}

///|
test "predicate conflict JSON is machine readable" {
  let conflict : @moontxnkit.TxnConflict = {
    kind: @moontxnkit.ConflictKind::PredicateWrite,
    key: "task:queued:3",
    snapshot_version: 4,
    current_version: 5,
    message: "phantom",
  }
  let json = conflict.to_json()
  assert_true(json.contains("\"kind\":\"predicate_write\""))
  assert_true(json.contains("\"key\":\"task:queued:3\""))
}
