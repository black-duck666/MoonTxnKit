///|
pub(all) struct WalRecord {
  transaction_id : Int
  snapshot_version : Int
  commit_version : Int
  operations : Array[WriteIntent]
  checksum : Int
} derive(Debug, Eq)

///|
fn checksum_text(value : String) -> Int {
  let mut hash = 216613
  for index = 0; index < value.length(); index = index + 1 {
    match value.get_char(index) {
      Some(ch) => hash = (hash * 167 + ch.to_int()) % 1000000007
      None => ()
    }
  }
  hash
}

///|
fn wal_checksum(
  transaction_id : Int,
  snapshot_version : Int,
  commit_version : Int,
  operations : Array[WriteIntent],
) -> Int {
  let mut checksum = (
      transaction_id * 31 + snapshot_version * 131 + commit_version * 521
    ) %
    1000000007
  for operation in operations {
    checksum = (checksum * 257 + checksum_text(operation.key)) % 1000000007
    checksum = match operation.value {
      Some(value) => (checksum * 257 + checksum_text(value) + 1) % 1000000007
      None => (checksum * 257 + 7) % 1000000007
    }
  }
  checksum
}

///|
pub fn WalRecord::new(
  transaction_id : Int,
  snapshot_version : Int,
  commit_version : Int,
  operations : Array[WriteIntent],
) -> WalRecord {
  let copied = operations.copy()
  {
    transaction_id,
    snapshot_version,
    commit_version,
    operations: copied,
    checksum: wal_checksum(
      transaction_id, snapshot_version, commit_version, copied,
    ),
  }
}

///|
pub fn WalRecord::is_valid(self : WalRecord) -> Bool {
  self.commit_version > self.snapshot_version &&
  self.operations.length() > 0 &&
  self.checksum ==
  wal_checksum(
    self.transaction_id,
    self.snapshot_version,
    self.commit_version,
    self.operations,
  )
}

///|
fn json_escape(value : String) -> String {
  let out = StringBuilder()
  for ch in value {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
pub fn WriteIntent::to_json(self : WriteIntent) -> String {
  match self.value {
    Some(value) =>
      "{\"key\":\"\{json_escape(self.key)}\",\"value\":\"\{json_escape(value)}\"}"
    None => "{\"key\":\"\{json_escape(self.key)}\",\"value\":null}"
  }
}

///|
pub fn WalRecord::to_json(self : WalRecord) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"transaction_id\":\{self.transaction_id},\"snapshot_version\":\{self.snapshot_version},\"commit_version\":\{self.commit_version},\"operations\":[",
  )
  for index, operation in self.operations {
    if index > 0 {
      out.write_char(',')
    }
    out.write_string(operation.to_json())
  }
  out.write_string("],\"checksum\":\{self.checksum}}")
  out.to_string()
}
