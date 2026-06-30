# Contribution Notes

MoonTxnKit treats transaction semantics as public contracts.

- Keep the core deterministic and free of platform IO.
- Add a regression test for every isolation or recovery change.
- Do not claim durability beyond the logical WAL interface.
- Keep commit messages focused on one reviewable capability.
- Run `moon fmt --check`, `moon check`, `moon test`, and `moon run cmd/main`.
