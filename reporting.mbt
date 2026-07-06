///|
fn conflict_kind_name(kind : ConflictKind) -> String {
  match kind {
    ConflictKind::WriteWrite => "write_write"
    ConflictKind::ReadWrite => "read_write"
    ConflictKind::PredicateWrite => "predicate_write"
    ConflictKind::InvalidState => "invalid_state"
    ConflictKind::InvalidSavepoint => "invalid_savepoint"
    ConflictKind::CorruptWal => "corrupt_wal"
  }
}

///|
pub fn TxnConflict::to_json(self : TxnConflict) -> String {
  "{\"kind\":\"\{conflict_kind_name(self.kind)}\",\"key\":\"\{json_escape(self.key)}\",\"snapshot_version\":\{self.snapshot_version},\"current_version\":\{self.current_version},\"message\":\"\{json_escape(self.message)}\"}"
}

///|
pub fn CommitResult::to_json(self : CommitResult) -> String {
  match self {
    CommitResult::CommittedAt(version) =>
      "{\"status\":\"committed\",\"commit_version\":\{version}}"
    CommitResult::Rejected(conflict) =>
      "{\"status\":\"rejected\",\"conflict\":\{conflict.to_json()}}"
  }
}

///|
pub fn VersionedValue::to_json(self : VersionedValue) -> String {
  let value = match self.value {
    Some(text) => "\"\{json_escape(text)}\""
    None => "null"
  }
  "{\"version\":\{self.version},\"value\":\{value}}"
}

///|
pub fn Engine::history(self : Engine, key : String) -> Array[VersionedValue] {
  match self.histories.get(key) {
    Some(history) => history.copy()
    None => []
  }
}

///|
pub fn Engine::history_json(self : Engine, key : String) -> String {
  let history = self.history(key)
  let out = StringBuilder()
  out.write_string("{\"key\":\"\{json_escape(key)}\",\"versions\":[")
  for index, entry in history {
    if index > 0 {
      out.write_char(',')
    }
    out.write_string(entry.to_json())
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn ValidationIssue::to_json(self : ValidationIssue) -> String {
  "{\"code\":\"\{json_escape(self.code)}\",\"key\":\"\{json_escape(self.key)}\",\"message\":\"\{json_escape(self.message)}\"}"
}
