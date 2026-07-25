# docs/

Documentation lives in one of six lifetime-based buckets, following the
convention `coding-agent-rulebook`'s `doctrine` plugin ships:

- `decisions/` — fixed at the moment a decision is made; not revised after.
- `handbooks/` — living how-to material, kept current.
- `reports/` — fixed to a point in time (postmortems, hunt findings, ablations).
- `specs/` — the state machine and other durable specifications this repo
  implements. See `specs/state-machine.md` for the ops role's state file,
  state field, transition table, and gate rules.
- `proposals/` — a request, its constraints, and its write set, frozen on
  approval.
- `_assets/` — images and other attachments referenced from the buckets above.

Directories with nothing to hold yet carry a `.gitkeep` so the layout is
visible before content exists.
