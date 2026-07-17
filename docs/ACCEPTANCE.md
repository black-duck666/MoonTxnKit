# OSC 2026 Acceptance Evidence

## Reproducible strict commands

```bash
moon fmt --check
moon check --deny-warn --target all
moon info && git diff --exit-code -- '*.mbti'
moon test --deny-warn --target all
moon run cmd/main --target js
moon run bench/main --target js
```

MoonBit 0.10.4 does not accept `--deny-warn` on `moon fmt` or `moon info`.
The CI workflow contains explicit named compatibility gates: it invokes those
arguments when supported, and otherwise runs the strict supported forms above.
This keeps the official four quality gates executable instead of preserving a
known-invalid command line.

## Production boundary

`Engine::snapshot` captures only committed histories and WAL records in stable
key order. `Engine::from_snapshot` rebuilds an engine without active handles.
File, database, browser, encryption, distributed lock, and crash-atomicity
policy belong to adapters; the core intentionally performs no platform I/O and
does not claim durability beyond its logical WAL/checkpoint boundary.

## Performance evidence

`bench/main` executes deterministic 1k, 10k, and 100k key workloads. Every
case seeds MVCC state, performs a Serializable prefix scan, introduces a
matching concurrent write, verifies the predicate conflict, and recovers from
logical WAL. It reports backend-independent state counts; wall-clock timing
must be recorded with the MoonBit version, backend, hardware, and raw command.
