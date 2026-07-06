///|
pub(all) enum IsolationLevel {
  Snapshot
  Serializable
} derive(Debug, Eq)

///|
pub(all) enum TxnState {
  Active
  Committed
  Aborted
} derive(Debug, Eq)

///|
pub(all) enum ConflictKind {
  WriteWrite
  ReadWrite
  PredicateWrite
  InvalidState
  InvalidSavepoint
  CorruptWal
} derive(Debug, Eq)

///|
pub(all) struct VersionedValue {
  version : Int
  value : String?
} derive(Debug, Eq)

///|
pub(all) struct WriteIntent {
  key : String
  value : String?
} derive(Debug, Eq)

///|
pub(all) struct ReadObservation {
  key : String
  observed_version : Int
} derive(Debug, Eq)

///|
pub(all) struct PrefixObservation {
  prefix : String
} derive(Debug, Eq)

///|
pub(all) struct KeyValue {
  key : String
  value : String
} derive(Debug, Eq)

///|
pub(all) struct Savepoint {
  name : String
  write_count : Int
  read_count : Int
  writes : Array[WriteIntent]
  reads : Array[ReadObservation]
  prefix_reads : Array[PrefixObservation]
} derive(Debug, Eq)

///|
pub(all) struct TxnConflict {
  kind : ConflictKind
  key : String
  snapshot_version : Int
  current_version : Int
  message : String
} derive(Debug, Eq)

///|
pub(all) enum CommitResult {
  CommittedAt(Int)
  Rejected(TxnConflict)
} derive(Debug, Eq)

///|
pub(all) struct EngineStats {
  current_version : Int
  keys : Int
  versions : Int
  active_transactions : Int
  committed_transactions : Int
  aborted_transactions : Int
  wal_records : Int
} derive(Debug, Eq)

///|
pub fn WriteIntent::put(key : String, value : String) -> WriteIntent {
  { key, value: Some(value) }
}

///|
pub fn WriteIntent::delete(key : String) -> WriteIntent {
  { key, value: None }
}
