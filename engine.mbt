///|
pub struct Engine {
  mut current_version : Int
  mut next_txn_id : Int
  histories : Map[String, Array[VersionedValue]]
  active_snapshots : Map[Int, Int]
  mut committed_transactions : Int
  mut aborted_transactions : Int
  wal_records : Array[WalRecord]
}

///|
pub struct Transaction {
  engine : Engine
  id : Int
  snapshot_version : Int
  isolation : IsolationLevel
  mut state : TxnState
  writes : Array[WriteIntent]
  reads : Array[ReadObservation]
  savepoints : Array[Savepoint]
}

///|
pub fn Engine::new() -> Engine {
  {
    current_version: 0,
    next_txn_id: 1,
    histories: {},
    active_snapshots: {},
    committed_transactions: 0,
    aborted_transactions: 0,
    wal_records: [],
  }
}

///|
pub fn Engine::version(self : Engine) -> Int {
  self.current_version
}

///|
pub fn Engine::begin(
  self : Engine,
  isolation? : IsolationLevel = IsolationLevel::Snapshot,
) -> Transaction {
  let id = self.next_txn_id
  self.next_txn_id = id + 1
  self.active_snapshots[id] = self.current_version
  {
    engine: self,
    id,
    snapshot_version: self.current_version,
    isolation,
    state: TxnState::Active,
    writes: [],
    reads: [],
    savepoints: [],
  }
}

///|
pub fn Transaction::id(self : Transaction) -> Int {
  self.id
}

///|
pub fn Transaction::snapshot(self : Transaction) -> Int {
  self.snapshot_version
}

///|
pub fn Transaction::status(self : Transaction) -> TxnState {
  self.state
}

///|
fn history_latest_version(history : Array[VersionedValue]) -> Int {
  if history.length() == 0 {
    0
  } else {
    history[history.length() - 1].version
  }
}

///|
fn history_read_at(
  history : Array[VersionedValue],
  version : Int,
) -> VersionedValue? {
  let mut index = history.length() - 1
  while index >= 0 {
    let entry = history[index]
    if entry.version <= version {
      return Some(entry)
    }
    index = index - 1
  }
  None
}

///|
pub fn Engine::read_at(self : Engine, key : String, version : Int) -> String? {
  match self.histories.get(key) {
    Some(history) =>
      match history_read_at(history, version) {
        Some(entry) => entry.value
        None => None
      }
    None => None
  }
}

///|
pub fn Engine::get(self : Engine, key : String) -> String? {
  self.read_at(key, self.current_version)
}

///|
fn Transaction::own_write(self : Transaction, key : String) -> WriteIntent? {
  let mut index = self.writes.length() - 1
  while index >= 0 {
    let write = self.writes[index]
    if write.key == key {
      return Some(write)
    }
    index = index - 1
  }
  None
}

///|
fn Transaction::record_read(
  self : Transaction,
  key : String,
  observed_version : Int,
) -> Unit {
  for read in self.reads {
    if read.key == key {
      return
    }
  }
  self.reads.push({ key, observed_version })
}

///|
pub fn Transaction::get(self : Transaction, key : String) -> String? {
  if self.state != TxnState::Active {
    return None
  }
  match self.own_write(key) {
    Some(write) => write.value
    None => {
      let observed = match self.engine.histories.get(key) {
        Some(history) =>
          match history_read_at(history, self.snapshot_version) {
            Some(entry) => entry
            None => VersionedValue::{ version: 0, value: None }
          }
        None => VersionedValue::{ version: 0, value: None }
      }
      self.record_read(key, observed.version)
      observed.value
    }
  }
}

///|
fn Transaction::replace_write(self : Transaction, intent : WriteIntent) -> Unit {
  for index, write in self.writes {
    if write.key == intent.key {
      self.writes[index] = intent
      return
    }
  }
  self.writes.push(intent)
}

///|
pub fn Transaction::put(
  self : Transaction,
  key : String,
  value : String,
) -> Bool {
  if self.state != TxnState::Active {
    return false
  }
  self.replace_write(WriteIntent::put(key, value))
  true
}

///|
pub fn Transaction::delete(self : Transaction, key : String) -> Bool {
  if self.state != TxnState::Active {
    return false
  }
  self.replace_write(WriteIntent::delete(key))
  true
}

///|
pub fn Transaction::pending_writes(self : Transaction) -> Int {
  self.writes.length()
}

///|
pub fn Transaction::savepoint(self : Transaction, name : String) -> Bool {
  if self.state != TxnState::Active || name.length() == 0 {
    return false
  }
  self.savepoints.push({
    name,
    write_count: self.writes.length(),
    read_count: self.reads.length(),
    writes: self.writes.copy(),
    reads: self.reads.copy(),
  })
  true
}

///|
pub fn Transaction::rollback_to(self : Transaction, name : String) -> Bool {
  if self.state != TxnState::Active {
    return false
  }
  let mut index = self.savepoints.length() - 1
  while index >= 0 {
    let savepoint = self.savepoints[index]
    if savepoint.name == name {
      self.writes.clear()
      for write in savepoint.writes {
        self.writes.push(write)
      }
      self.reads.clear()
      for read in savepoint.reads {
        self.reads.push(read)
      }
      self.savepoints.truncate(index + 1)
      return true
    }
    index = index - 1
  }
  false
}

///|
pub fn Transaction::release_savepoint(
  self : Transaction,
  name : String,
) -> Bool {
  if self.state != TxnState::Active {
    return false
  }
  let mut index = self.savepoints.length() - 1
  while index >= 0 {
    if self.savepoints[index].name == name {
      ignore(self.savepoints.remove(index))
      return true
    }
    index = index - 1
  }
  false
}

///|
pub fn Transaction::savepoint_count(self : Transaction) -> Int {
  self.savepoints.length()
}

///|
fn Transaction::reject(
  self : Transaction,
  kind : ConflictKind,
  key : String,
  current_version : Int,
  message : String,
) -> CommitResult {
  self.state = TxnState::Aborted
  ignore(self.engine.active_snapshots.remove(self.id))
  self.engine.aborted_transactions = self.engine.aborted_transactions + 1
  CommitResult::Rejected({
    kind,
    key,
    snapshot_version: self.snapshot_version,
    current_version,
    message,
  })
}

///|
fn Engine::latest_version_for(self : Engine, key : String) -> Int {
  match self.histories.get(key) {
    Some(history) => history_latest_version(history)
    None => 0
  }
}

///|
fn Transaction::validate_serializable(self : Transaction) -> TxnConflict? {
  if self.isolation != IsolationLevel::Serializable {
    return None
  }
  for read in self.reads {
    let latest = self.engine.latest_version_for(read.key)
    if latest > self.snapshot_version {
      return Some({
        kind: ConflictKind::ReadWrite,
        key: read.key,
        snapshot_version: self.snapshot_version,
        current_version: latest,
        message: "read key changed after transaction snapshot",
      })
    }
  }
  None
}

///|
pub fn Transaction::commit(self : Transaction) -> CommitResult {
  if self.state != TxnState::Active {
    return CommitResult::Rejected({
      kind: ConflictKind::InvalidState,
      key: "",
      snapshot_version: self.snapshot_version,
      current_version: self.engine.current_version,
      message: "transaction is not active",
    })
  }
  for write in self.writes {
    let latest = self.engine.latest_version_for(write.key)
    if latest > self.snapshot_version {
      return self.reject(
        ConflictKind::WriteWrite,
        write.key,
        latest,
        "key changed after transaction snapshot",
      )
    }
  }
  match self.validate_serializable() {
    Some(conflict) =>
      return self.reject(
        conflict.kind,
        conflict.key,
        conflict.current_version,
        conflict.message,
      )
    None => ()
  }
  let commit_version = if self.writes.length() == 0 {
    self.engine.current_version
  } else {
    self.engine.current_version + 1
  }
  if self.writes.length() > 0 {
    self.engine.wal_records.push(
      WalRecord::new(
        self.id,
        self.snapshot_version,
        commit_version,
        self.writes,
      ),
    )
    self.engine.current_version = commit_version
    for write in self.writes {
      let history = match self.engine.histories.get(write.key) {
        Some(existing) => existing
        None => []
      }
      history.push({ version: commit_version, value: write.value })
      self.engine.histories[write.key] = history
    }
  }
  self.state = TxnState::Committed
  ignore(self.engine.active_snapshots.remove(self.id))
  self.engine.committed_transactions = self.engine.committed_transactions + 1
  CommitResult::CommittedAt(commit_version)
}

///|
pub fn Engine::wal(self : Engine) -> Array[WalRecord] {
  self.wal_records.copy()
}

///|
pub fn Transaction::abort(self : Transaction) -> Bool {
  if self.state != TxnState::Active {
    return false
  }
  self.state = TxnState::Aborted
  ignore(self.engine.active_snapshots.remove(self.id))
  self.engine.aborted_transactions = self.engine.aborted_transactions + 1
  true
}
