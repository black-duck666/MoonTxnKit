///|
pub(all) struct CompactionReport {
  low_watermark : Int
  removed_versions : Int
  retained_versions : Int
  removed_keys : Int
} derive(Debug, Eq)

///|
pub(all) struct ValidationIssue {
  code : String
  key : String
  message : String
} derive(Debug, Eq)

///|
pub fn Engine::oldest_active_snapshot(self : Engine) -> Int {
  let mut oldest = self.current_version
  let mut found = false
  for _, snapshot in self.active_snapshots {
    if !found || snapshot < oldest {
      oldest = snapshot
      found = true
    }
  }
  oldest
}

///|
pub fn Engine::compact(self : Engine) -> CompactionReport {
  let low_watermark = self.oldest_active_snapshot()
  let keys : Array[String] = []
  for key, _ in self.histories {
    keys.push(key)
  }
  let mut removed_versions = 0
  let mut retained_versions = 0
  let mut removed_keys = 0
  for key in keys {
    let history = match self.histories.get(key) {
      Some(value) => value
      None => continue
    }
    let mut anchor = -1
    for index, entry in history {
      if entry.version <= low_watermark {
        anchor = index
      }
    }
    let retained : Array[VersionedValue] = []
    if anchor >= 0 {
      retained.push(history[anchor])
    }
    for entry in history {
      if entry.version > low_watermark {
        retained.push(entry)
      }
    }
    removed_versions = removed_versions + history.length() - retained.length()
    if retained.length() == 1 &&
      retained[0].value is None &&
      self.active_snapshots.length() == 0 {
      ignore(self.histories.remove(key))
      removed_keys = removed_keys + 1
    } else {
      self.histories[key] = retained
      retained_versions = retained_versions + retained.length()
    }
  }
  { low_watermark, removed_versions, retained_versions, removed_keys }
}

///|
pub fn Engine::stats(self : Engine) -> EngineStats {
  let mut versions = 0
  for _, history in self.histories {
    versions = versions + history.length()
  }
  {
    current_version: self.current_version,
    keys: self.histories.length(),
    versions,
    active_transactions: self.active_snapshots.length(),
    committed_transactions: self.committed_transactions,
    aborted_transactions: self.aborted_transactions,
    wal_records: self.wal_records.length(),
  }
}

///|
pub fn Engine::validate(self : Engine) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  for key, history in self.histories {
    let mut previous = 0
    for entry in history {
      if entry.version <= previous || entry.version > self.current_version {
        issues.push({
          code: "VERSION_ORDER",
          key,
          message: "history versions must increase and not exceed engine version",
        })
      }
      previous = entry.version
    }
  }
  let mut wal_version = 0
  for record in self.wal_records {
    if !record.is_valid() {
      issues.push({
        code: "WAL_CHECKSUM",
        key: "",
        message: "WAL record checksum is invalid",
      })
    }
    if record.commit_version <= wal_version {
      issues.push({
        code: "WAL_ORDER",
        key: "",
        message: "WAL commit versions must increase",
      })
    }
    wal_version = record.commit_version
  }
  issues
}

///|
pub fn CompactionReport::to_json(self : CompactionReport) -> String {
  "{\"low_watermark\":\{self.low_watermark},\"removed_versions\":\{self.removed_versions},\"retained_versions\":\{self.retained_versions},\"removed_keys\":\{self.removed_keys}}"
}

///|
pub fn EngineStats::to_json(self : EngineStats) -> String {
  "{\"current_version\":\{self.current_version},\"keys\":\{self.keys},\"versions\":\{self.versions},\"active_transactions\":\{self.active_transactions},\"committed_transactions\":\{self.committed_transactions},\"aborted_transactions\":\{self.aborted_transactions},\"wal_records\":\{self.wal_records}}"
}
