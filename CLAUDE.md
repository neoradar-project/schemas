# CLAUDE.md

## The NeoRadar constellation

Six repos, developed together. Cross-repo references use `@id` tokens, never paths:
`@client` (C# radar client), `@server` (Go compute tier), `@hub` (JS management dashboard),
`@cli` (JS package and dataset build pipeline), `@schemas` (shared JSON Schemas), `@pluginsdk` (C#
plugin SDK, vendored into `@client` at `extern/NeoRadar.PluginSdk`). Data ids:
`@packages` (built packages), `@sectorsrc` (CLI source sector files), `@data` (runtime data root).

Resolve an id in this order: the `NEORADAR_<ID>_DIR` env var; then `neoradar.repos.local.json`
at this repo root (gitignored, per-machine); then an upward scan using the `defaultSubpaths` in
`neoradar.repos.json`. If an id does not resolve, say so and work from this repo alone. Never
guess a path. A sibling repo is normally ABSENT in CI, which is the expected case, not an error.

These pairs move in LOCKSTEP. A one-sided edit is a break, not a cleanup:
- `@server/internal/contract/` and `@client/src/NeoRadar.Core/ServerLink/Contract/`
- `@server/internal/contract/testdata/*.json` and `@client/tests/NeoRadar.Core.Tests/ServerLink/Vectors/*.json`
- `@server/internal/contract/vocabulary.json` and `@client/tests/NeoRadar.Core.Tests/ServerLink/vocabulary.json`

Stance: alpha. Do not write backwards-compatibility or fallback layers unless asked, especially
in ServerLink. Document any process change and how it rolls out to other sector files. The
infrastructure serves thousands of users, so handle failure paths and never swallow an error.
Never add `Co-Authored-By` or any AI attribution to a commit or PR.

This block is identical in all six repos. Editing one copy alone is a break.

## What this repo is

The JSON Schemas for the NeoRadar package format: `package/manifest.schema.json`,
`profile.schema.json`, `systems/{expressions,labels,lists,mapstyle,targets}.schema.json`. No
code, no build, no tests. Consumers: source sector files (`@sectorsrc`) reference them by raw
URL on `main` (`.../schemas/refs/heads/main/systems/targets.schema.json`), so authors' editors
validate live; `@cli` builds those files into packages; `@client` parses the same files at load
time (`Package/`, `Utils/Expressions/`) and is the real arbiter of what a package may hold.

## Keeping up with @client

`@client` is the arbiter, and nothing structural binds the two, so a property added to a config
model just silently fails to appear in authors' completion. That is how `textWeight` and
`textSharpness` reached `labels.schema.json` but not the copy of `tagItem` inside
`lists.schema.json`: the tag-item shape is duplicated between those two files and only one was
updated.

`@client`'s `SystemsSchemaDriftTests` is the guard. It resolves this repo through
`ConstellationRepos`, skips when absent (the normal CI case), and asserts that each schema's
property names and the matching models' `[JsonPropertyName]` names are the same SET - both
directions, so a schema advertising something the parser ignores fails too. It checks presence
only: types, ranges, enums and descriptions carry intent no C# property expresses, which is why
these schemas stay hand-written rather than generated. `mapstyle.schema.json` has no case because
`MapStyleParser` reads it by hand with nothing to reflect over; it needs eyes.

**Authors validate against raw `main`, not your branch.** A schema sitting correct on a feature
branch is invisible to every sector file until it merges, and the symptom is "the client accepts
this but my editor says it is invalid".

## The one rule

There is no schema versioning and no pinned ref, so a merge to `main` is instantly live for
every sector-file author. A schema change IS a package-format change: it needs the matching
`@cli` change, the matching `@client` parser change, and a written rollout path for existing
sector files. Widening (a new optional property) is safe. Narrowing, renaming, or making a
property required breaks live authors and must never land alone.
