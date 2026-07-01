///|
test "new engine starts at version zero" {
  let engine = @moontxnkit.Engine::new()
  assert_eq(engine.version(), 0)
  assert_true(engine.get("missing") is None)
}

///|
test "committed value is visible at its commit version" {
  let engine = @moontxnkit.Engine::new()
  let txn = engine.begin()
  assert_true(txn.put("name", "moon"))
  assert_true(txn.commit() == @moontxnkit.CommitResult::CommittedAt(1))
  assert_true(engine.get("name") == Some("moon"))
  assert_true(engine.read_at("name", 0) is None)
  assert_true(engine.read_at("name", 1) == Some("moon"))
}

///|
test "transaction reads its own pending write" {
  let engine = @moontxnkit.Engine::new()
  let txn = engine.begin()
  assert_true(txn.put("key", "first"))
  assert_true(txn.put("key", "second"))
  assert_eq(txn.pending_writes(), 1)
  assert_true(txn.get("key") == Some("second"))
}

///|
test "snapshot read remains repeatable after concurrent commit" {
  let engine = @moontxnkit.Engine::new()
  let seed = engine.begin()
  ignore(seed.put("counter", "1"))
  ignore(seed.commit())
  let reader = engine.begin()
  assert_true(reader.get("counter") == Some("1"))
  let writer = engine.begin()
  ignore(writer.put("counter", "2"))
  assert_true(writer.commit() == @moontxnkit.CommitResult::CommittedAt(2))
  assert_true(reader.get("counter") == Some("1"))
  assert_true(engine.get("counter") == Some("2"))
}

///|
test "snapshot isolation rejects concurrent writes to same key" {
  let engine = @moontxnkit.Engine::new()
  let first = engine.begin()
  let second = engine.begin()
  ignore(first.put("balance", "90"))
  ignore(second.put("balance", "80"))
  assert_true(first.commit() == @moontxnkit.CommitResult::CommittedAt(1))
  match second.commit() {
    @moontxnkit.CommitResult::Rejected(conflict) => {
      assert_true(conflict.kind == @moontxnkit.ConflictKind::WriteWrite)
      assert_eq(conflict.key, "balance")
      assert_eq(conflict.current_version, 1)
    }
    _ => fail("second writer should be rejected")
  }
}

///|
test "delete creates a historical tombstone" {
  let engine = @moontxnkit.Engine::new()
  let create = engine.begin()
  ignore(create.put("session", "active"))
  ignore(create.commit())
  let remove = engine.begin()
  assert_true(remove.delete("session"))
  assert_true(remove.commit() == @moontxnkit.CommitResult::CommittedAt(2))
  assert_true(engine.read_at("session", 1) == Some("active"))
  assert_true(engine.get("session") is None)
}

///|
test "read only commit does not advance engine version" {
  let engine = @moontxnkit.Engine::new()
  let txn = engine.begin()
  assert_true(txn.get("none") is None)
  assert_true(txn.commit() == @moontxnkit.CommitResult::CommittedAt(0))
  assert_eq(engine.version(), 0)
}

///|
test "aborted transaction cannot commit" {
  let engine = @moontxnkit.Engine::new()
  let txn = engine.begin()
  ignore(txn.put("key", "value"))
  assert_true(txn.abort())
  assert_true(txn.status() == @moontxnkit.TxnState::Aborted)
  match txn.commit() {
    @moontxnkit.CommitResult::Rejected(conflict) =>
      assert_true(conflict.kind == @moontxnkit.ConflictKind::InvalidState)
    _ => fail("aborted transaction cannot commit")
  }
  assert_true(engine.get("key") is None)
}
