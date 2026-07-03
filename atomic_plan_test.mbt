///|
fn seed_value(
  engine : @moontxnkit.Engine,
  key : String,
  value : String,
) -> Unit {
  let transaction = engine.begin()
  ignore(transaction.put(key, value))
  ignore(transaction.commit())
}

///|
test "atomic plan claims queued workflow task once" {
  let engine = @moontxnkit.Engine::new()
  seed_value(engine, "task:42:state", "queued")
  let plan = @moontxnkit.AtomicPlan::new("claim-task")
    .expect("task:42:state", "queued")
    .expect_missing("task:42:owner")
    .put("task:42:state", "running")
    .put("task:42:owner", "worker-7")
  assert_true(engine.execute(plan) == @moontxnkit.PlanResult::AppliedAt(2))
  assert_true(engine.get("task:42:state") == Some("running"))
  assert_true(engine.get("task:42:owner") == Some("worker-7"))
}

///|
test "failed condition leaves every state key unchanged" {
  let engine = @moontxnkit.Engine::new()
  seed_value(engine, "order:9:state", "cancelled")
  let before = engine.version()
  let plan = @moontxnkit.AtomicPlan::new("reserve-order")
    .expect("order:9:state", "pending")
    .put("order:9:state", "reserved")
    .put("inventory:sku-1", "4")
  match engine.execute(plan) {
    @moontxnkit.PlanResult::ConditionFailed(failure) => {
      assert_eq(failure.plan, "reserve-order")
      assert_eq(failure.key, "order:9:state")
      assert_true(failure.expected == Some("pending"))
      assert_true(failure.actual == Some("cancelled"))
    }
    _ => fail("mismatched business precondition must reject the plan")
  }
  assert_eq(engine.version(), before)
  assert_true(engine.get("order:9:state") == Some("cancelled"))
  assert_true(engine.get("inventory:sku-1") is None)
}

///|
test "inventory reservation commits related keys at one version" {
  let engine = @moontxnkit.Engine::new()
  let seed = engine.begin()
  ignore(seed.put("inventory:sku-1", "5"))
  ignore(seed.put("order:9:state", "pending"))
  ignore(seed.commit())
  let plan = @moontxnkit.AtomicPlan::new("reserve-inventory")
    .expect("inventory:sku-1", "5")
    .expect("order:9:state", "pending")
    .put("inventory:sku-1", "4")
    .put("order:9:state", "reserved")
    .put("order:9:reservation", "sku-1")
  assert_true(engine.execute(plan) == @moontxnkit.PlanResult::AppliedAt(2))
  assert_eq(engine.history("inventory:sku-1")[1].version, 2)
  assert_eq(engine.history("order:9:state")[1].version, 2)
  assert_eq(engine.history("order:9:reservation")[0].version, 2)
}

///|
test "plan can guard and delete idempotency marker" {
  let engine = @moontxnkit.Engine::new()
  seed_value(engine, "job:token", "leased")
  let plan = @moontxnkit.AtomicPlan::new("release-lease")
    .expect("job:token", "leased")
    .delete("job:token")
  assert_true(engine.execute(plan) == @moontxnkit.PlanResult::AppliedAt(2))
  assert_true(engine.get("job:token") is None)
}

///|
test "last plan write wins without increasing write count" {
  let plan = @moontxnkit.AtomicPlan::new("configure")
    .put("feature:mode", "observe")
    .put("feature:mode", "enforce")
  assert_eq(plan.condition_count(), 0)
  assert_eq(plan.write_count(), 1)
  let engine = @moontxnkit.Engine::new()
  ignore(engine.execute(plan))
  assert_true(engine.get("feature:mode") == Some("enforce"))
}

///|
test "condition failure has stable JSON evidence" {
  let engine = @moontxnkit.Engine::new()
  let result = engine.execute(
    @moontxnkit.AtomicPlan::new("deduplicate")
    .expect_missing("event:7")
    .put("event:7", "processed"),
  )
  assert_true(
    result.to_json() == "{\"status\":\"applied\",\"commit_version\":1}",
  )
  let rejected = engine.execute(
    @moontxnkit.AtomicPlan::new("deduplicate")
    .expect_missing("event:7")
    .put("event:7", "processed-again"),
  )
  assert_true(rejected.to_json().contains("\"status\":\"condition_failed\""))
  assert_true(rejected.to_json().contains("\"plan\":\"deduplicate\""))
}
