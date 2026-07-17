///|
fn run_workload(key_count : Int) -> Unit {
  let engine = @txn.Engine::new()
  let seed = engine.begin()
  for index = 0; index < key_count; index = index + 1 {
    ignore(seed.put("inventory:item-\{index}", "available"))
  }
  let seed_result = seed.commit()

  let scanner = engine.begin(isolation=@txn.IsolationLevel::Serializable)
  let rows = scanner.scan_prefix("inventory:")
  let first_key = if rows.length() > 0 { rows[0].key } else { "" }
  let last_key = if rows.length() > 0 {
    rows[rows.length() - 1].key
  } else {
    ""
  }

  let writer = engine.begin()
  ignore(writer.put("inventory:new-item", "available"))
  let writer_result = writer.commit()
  ignore(scanner.put("audit:inventory", "scanned"))
  let scanner_result = scanner.commit()

  let wal = engine.wal()
  let (recovered, recovery) = @txn.Engine::recover(wal)
  println(
    "workload keys=\{key_count} rows=\{rows.length()} first=\{first_key} last=\{last_key} seed=\{seed_result.to_json()} writer=\{writer_result.to_json()} scanner=\{scanner_result.to_json()} wal_records=\{wal.length()} recovery=\{recovery.to_json()} recovered_keys=\{recovered.stats().keys} validation_issues=\{recovered.validate().length()}",
  )
}

///|
fn main {
  // The values are portable operation counts; record timing externally with
  // the exact MoonBit backend, hardware, and command line.
  for key_count in [1000, 10000, 100000] {
    run_workload(key_count)
  }
}
