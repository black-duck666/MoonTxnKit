///|
fn show_value(value : String?) -> String {
  match value {
    Some(text) => text
    None => "<missing>"
  }
}

///|
fn main {
  let engine = @txn.Engine::new()

  let seed = engine.begin()
  ignore(seed.put("account-a", "100"))
  ignore(seed.put("account-b", "100"))
  println("seed=" + seed.commit().to_json())

  let long_reader = engine.begin()
  println("reader_snapshot=\{long_reader.snapshot()}")
  println("reader_before=" + show_value(long_reader.get("account-a")))

  let transfer = engine.begin(isolation=@txn.IsolationLevel::Serializable)
  ignore(transfer.get("account-a"))
  ignore(transfer.get("account-b"))
  ignore(transfer.put("account-a", "70"))
  ignore(transfer.put("account-b", "130"))
  println("transfer=" + transfer.commit().to_json())
  println("reader_after=" + show_value(long_reader.get("account-a")))
  println("current_after=" + show_value(engine.get("account-a")))

  let first = engine.begin()
  let second = engine.begin()
  ignore(first.put("account-a", "60"))
  ignore(second.put("account-a", "50"))
  println("first_writer=" + first.commit().to_json())
  println("second_writer=" + second.commit().to_json())

  let task_seed = engine.begin()
  ignore(task_seed.put("task:42:state", "queued"))
  ignore(task_seed.commit())
  let claim = @txn.AtomicPlan::new("claim-task")
    .expect("task:42:state", "queued")
    .expect_missing("task:42:owner")
    .put("task:42:state", "running")
    .put("task:42:owner", "worker-7")
  println("claim_task=" + engine.execute(claim).to_json())
  let duplicate_claim = @txn.AtomicPlan::new("claim-task")
    .expect("task:42:state", "queued")
    .expect_missing("task:42:owner")
    .put("task:42:state", "running")
    .put("task:42:owner", "worker-8")
  println("duplicate_claim=" + engine.execute(duplicate_claim).to_json())

  let slot_reader = engine.begin(isolation=@txn.IsolationLevel::Serializable)
  println("available_slots_before=\{slot_reader.scan_prefix("slot:").length()}")
  let slot_writer = engine.begin()
  ignore(slot_writer.put("slot:a", "reserved"))
  println("reserve_slot=" + slot_writer.commit().to_json())
  ignore(slot_reader.put("audit:slot-scan", "observed-empty"))
  println("phantom_guard=" + slot_reader.commit().to_json())

  println("history=" + engine.history_json("account-a"))
  println("stats=" + engine.stats().to_json())

  let wal = engine.wal()
  let (recovered, replay) = @txn.Engine::recover(wal)
  println("replay=" + replay.to_json())
  println("recovered=" + recovered.stats().to_json())

  println("compact_active=" + engine.compact().to_json())
  ignore(long_reader.abort())
  println("compact_idle=" + engine.compact().to_json())
  println("validation_issues=\{engine.validate().length()}")
}
