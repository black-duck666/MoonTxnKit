///|
pub(all) struct ReplayReport {
  applied_records : Int
  skipped_records : Int
  last_version : Int
  valid : Bool
  error : String
} derive(Debug, Eq)

///|
fn Engine::wal_checksum_at(self : Engine, commit_version : Int) -> Int? {
  for record in self.wal_records {
    if record.commit_version == commit_version {
      return Some(record.checksum)
    }
  }
  None
}

///|
fn replay_failure(
  engine : Engine,
  applied : Int,
  skipped : Int,
  message : String,
) -> ReplayReport {
  {
    applied_records: applied,
    skipped_records: skipped,
    last_version: engine.current_version,
    valid: false,
    error: message,
  }
}

///|
pub fn Engine::replay(
  self : Engine,
  records : Array[WalRecord],
) -> ReplayReport {
  let mut expected = self.current_version + 1
  let mut skipped = 0
  for record in records {
    if !record.is_valid() {
      return replay_failure(self, 0, skipped, "WAL checksum is invalid")
    }
    if record.commit_version <= self.current_version {
      match self.wal_checksum_at(record.commit_version) {
        Some(checksum) if checksum != record.checksum =>
          return replay_failure(
            self, 0, skipped, "duplicate WAL version has different checksum",
          )
        _ => skipped = skipped + 1
      }
    } else {
      if record.commit_version != expected {
        return replay_failure(self, 0, skipped, "WAL commit version has a gap")
      }
      expected = expected + 1
    }
  }

  let mut applied = 0
  for record in records {
    if record.commit_version <= self.current_version {
      continue
    }
    for operation in record.operations {
      let history = match self.histories.get(operation.key) {
        Some(existing) => existing
        None => []
      }
      history.push({ version: record.commit_version, value: operation.value })
      self.histories[operation.key] = history
    }
    self.current_version = record.commit_version
    self.wal_records.push(record)
    if record.transaction_id >= self.next_txn_id {
      self.next_txn_id = record.transaction_id + 1
    }
    self.committed_transactions = self.committed_transactions + 1
    applied = applied + 1
  }
  {
    applied_records: applied,
    skipped_records: skipped,
    last_version: self.current_version,
    valid: true,
    error: "",
  }
}

///|
pub fn Engine::recover(records : Array[WalRecord]) -> (Engine, ReplayReport) {
  let engine = Engine::new()
  let report = engine.replay(records)
  (engine, report)
}

///|
pub fn ReplayReport::to_json(self : ReplayReport) -> String {
  "{\"applied_records\":\{self.applied_records},\"skipped_records\":\{self.skipped_records},\"last_version\":\{self.last_version},\"valid\":\{self.valid},\"error\":\"\{json_escape(self.error)}\"}"
}
