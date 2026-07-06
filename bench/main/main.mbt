///|
fn main {
  let key_count = 10000
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
  println("keys=\{key_count}")
  println("seed=" + seed_result.to_json())
  println("scan_rows=\{rows.length()}")
  println("scan_first=\{first_key}")
  println("scan_last=\{last_key}")
  println("writer=" + writer_result.to_json())
  println("scanner=" + scanner_result.to_json())
  println("wal_records=\{wal.length()}")
  println("recovery=" + recovery.to_json())
  println("recovered_keys=\{recovered.stats().keys}")
  println("validation_issues=\{recovered.validate().length()}")
}
