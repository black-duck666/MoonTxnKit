///|
pub(all) struct PlanCondition {
  key : String
  expected : String?
} derive(Debug, Eq)

///|
pub(all) struct ConditionFailure {
  plan : String
  key : String
  expected : String?
  actual : String?
  snapshot_version : Int
} derive(Debug, Eq)

///|
pub(all) enum PlanResult {
  AppliedAt(Int)
  ConditionFailed(ConditionFailure)
  CommitRejected(TxnConflict)
} derive(Debug, Eq)

///|
pub struct AtomicPlan {
  name : String
  isolation : IsolationLevel
  conditions : Array[PlanCondition]
  writes : Array[WriteIntent]
}

///|
pub fn AtomicPlan::new(
  name : String,
  isolation? : IsolationLevel = IsolationLevel::Serializable,
) -> AtomicPlan {
  { name, isolation, conditions: [], writes: [] }
}

///|
pub fn AtomicPlan::name(self : AtomicPlan) -> String {
  self.name
}

///|
pub fn AtomicPlan::expect(
  self : AtomicPlan,
  key : String,
  value : String,
) -> AtomicPlan {
  self.conditions.push({ key, expected: Some(value) })
  self
}

///|
pub fn AtomicPlan::expect_missing(
  self : AtomicPlan,
  key : String,
) -> AtomicPlan {
  self.conditions.push({ key, expected: None })
  self
}

///|
fn AtomicPlan::replace_write(self : AtomicPlan, intent : WriteIntent) -> Unit {
  for index, write in self.writes {
    if write.key == intent.key {
      self.writes[index] = intent
      return
    }
  }
  self.writes.push(intent)
}

///|
pub fn AtomicPlan::put(
  self : AtomicPlan,
  key : String,
  value : String,
) -> AtomicPlan {
  self.replace_write(WriteIntent::put(key, value))
  self
}

///|
pub fn AtomicPlan::delete(self : AtomicPlan, key : String) -> AtomicPlan {
  self.replace_write(WriteIntent::delete(key))
  self
}

///|
pub fn AtomicPlan::condition_count(self : AtomicPlan) -> Int {
  self.conditions.length()
}

///|
pub fn AtomicPlan::write_count(self : AtomicPlan) -> Int {
  self.writes.length()
}

///|
pub fn Engine::execute(self : Engine, plan : AtomicPlan) -> PlanResult {
  let transaction = self.begin(isolation=plan.isolation)
  for condition in plan.conditions {
    let actual = transaction.get(condition.key)
    if actual != condition.expected {
      ignore(transaction.abort())
      return PlanResult::ConditionFailed({
        plan: plan.name,
        key: condition.key,
        expected: condition.expected,
        actual,
        snapshot_version: transaction.snapshot(),
      })
    }
  }
  for write in plan.writes {
    match write.value {
      Some(value) => ignore(transaction.put(write.key, value))
      None => ignore(transaction.delete(write.key))
    }
  }
  match transaction.commit() {
    CommitResult::CommittedAt(version) => PlanResult::AppliedAt(version)
    CommitResult::Rejected(conflict) => PlanResult::CommitRejected(conflict)
  }
}

///|
pub fn ConditionFailure::to_json(self : ConditionFailure) -> String {
  let expected = match self.expected {
    Some(value) => "\"\{json_escape(value)}\""
    None => "null"
  }
  let actual = match self.actual {
    Some(value) => "\"\{json_escape(value)}\""
    None => "null"
  }
  "{\"plan\":\"\{json_escape(self.plan)}\",\"key\":\"\{json_escape(self.key)}\",\"expected\":\{expected},\"actual\":\{actual},\"snapshot_version\":\{self.snapshot_version}}"
}

///|
pub fn PlanResult::to_json(self : PlanResult) -> String {
  match self {
    PlanResult::AppliedAt(version) =>
      "{\"status\":\"applied\",\"commit_version\":\{version}}"
    PlanResult::ConditionFailed(failure) =>
      "{\"status\":\"condition_failed\",\"failure\":\{failure.to_json()}}"
    PlanResult::CommitRejected(conflict) =>
      "{\"status\":\"commit_rejected\",\"conflict\":\{conflict.to_json()}}"
  }
}
