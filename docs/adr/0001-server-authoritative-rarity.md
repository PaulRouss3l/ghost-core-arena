# Rarity is decided by the server, not the mod

Rarity sets ship prices and Shop odds, so a player who edits it gains an unfair Ghost Fleet. Any file
or constant inside the mod can be edited locally, so the mod only reports hull facts (id, DP,
`rare_bp`, `rarity` column, hints, skin base) for its mod-set fingerprint; the server applies the
formula, its tunables and its curated override table, and returns hull → Rarity. The server caches
the table per fingerprint, flags clients whose facts differ for the same fingerprint, and rejects
snapshots that break the table.

## Considered options

- Tunables and an override CSV in the mod, plus a hash of the resolved table in the match
  fingerprint: tampering would only isolate the tamperer, but the rules would still ship in the
  mod and other mods could rate their own hulls.
- Hard-coded Java constants: harder to edit, not prevented.

## Consequences

- Other mods cannot rate their own hulls; we add server-side override rows when needed.
- Offline (bots-only) Runs use the last table the server sent for that fingerprint, else a
  built-in copy of the formula with no overrides. Those Runs never upload.
