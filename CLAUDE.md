# CLAUDE.md

<!-- shared:constellation -->
## The NeoRadar constellation

Six repos, developed together. Cross-repo references use `@id` tokens, never paths: `@client` (C# radar
client), `@server` (Go compute tier), `@hub` (JS management dashboard), `@cli` (JS package and dataset
build pipeline), `@schemas` (shared JSON Schemas), `@pluginsdk` (C# plugin SDK, vendored into `@client` at
`extern/NeoRadar.PluginSdk`). Data: `@packages` (built packages), `@sectorsrc` (CLI source sector files),
`@data` (runtime data root). An id resolves through the `NEORADAR_<ID>_DIR` env var, then
`neoradar.repos.local.json` at the repo root (gitignored, per-machine), then an upward scan using the
`defaultSubpaths` in `neoradar.repos.json`. If it does not resolve, say so and work from this repo alone;
never guess a path. A sibling repo is normally absent in CI, and that is not an error.

These pairs move in LOCKSTEP; a one-sided edit is a break, not a cleanup:
- `@server/internal/contract/` and `@client/src/NeoRadar.Core/ServerLink/Contract/`
- `@server/internal/contract/testdata/*.json` and `@client/tests/NeoRadar.Core.Tests/ServerLink/Vectors/*.json`
- `@server/internal/contract/vocabulary.json` and `@client/tests/NeoRadar.Core.Tests/ServerLink/vocabulary.json`
- `@server/internal/trajectory/testdata/copx-matcher-cases.json` and
  `@client/tests/NeoRadar.Core.Tests/FutureOwnership/Copx/copx-matcher-cases.json`

Alpha: no backwards-compatibility or fallback layers unless asked, especially in ServerLink. Every process
or data-format change states how it rolls out to the existing sector files. Thousands of controllers use
this, so failure paths are handled and logged, never swallowed. Commits are signed (never `--no-verify`,
never bypass signing), made only when asked and never pushed unless asked; no commit or PR carries
`Co-Authored-By` or any other AI attribution. This block is identical in all six repos.
<!-- /shared:constellation -->

## What this repo is

The JSON Schemas for the NeoRadar package format: `package/manifest.schema.json`,
`profile.schema.json`, `systems/{expressions,labels,lists,mapstyle,policy,shapes,targets}.schema.json`,
the `datasets/` files, `injector/scenario.schema.json`, and the sector source's `data/` files. No
code, no build, no tests. Consumers: source sector files (`@sectorsrc`) reference them by raw
URL on `main` (`.../schemas/refs/heads/main/systems/targets.schema.json`), so authors' editors
validate live; `@cli` builds those files into packages; `@client` parses the same files at load
time (`Package/`, `Utils/Expressions/`) and is the real arbiter of what a package may hold.

`injector/scenario.schema.json` is the odd one out: it is not a package file. It documents the
scenario format of `@client/tools/NeoRadar.Injector`, which no package carries and `@cli` never
builds, and it is draft 2020-12 where the package schemas are draft-07. `SystemsSchemaDriftTests`
does not cover it, and the injector validates by hand rather than against it: this file is the
written format and the arbiter, and `ScenarioValidator` plus `JsonScenarioParser` are what enforce
it. The two move together or authors get completion for a field the tool drops.

## Keeping up with @client

`@client` is the arbiter, and nothing structural binds the two, so a property added to a config
model just silently fails to appear in authors' completion. That is how `textWeight` and
`textSharpness` reached `labels.schema.json` but not the copy of `tagItem` inside
`lists.schema.json`: the tag-item shape is duplicated between those two files and only one was
updated.

`@client`'s `SystemsSchemaDriftTests` is the guard for property names; `SchemaVocabularyDriftTests` is the
enum half (below). It resolves this repo through
`ConstellationRepos`, skips when absent (the normal CI case), and asserts that each schema's
property names and the matching models' `[JsonPropertyName]` names are the same SET - both
directions, so a schema advertising something the parser ignores fails too. It checks presence
only: types, ranges, enums and descriptions carry intent no C# property expresses, which is why
these schemas stay hand-written rather than generated. `mapstyle.schema.json` has no case because
`MapStyleParser` reads it by hand with nothing to reflect over; it needs eyes.

**A schema change is not finished here.** A property added or changed in a `systems/`, manifest or
profile schema also needs `@client`'s Configurator to edit it or preserve it on save. A
Configurator section edited as a document pins a copy of its schema in `@client`'s test project
and fails when a property is neither a declared field nor excused with a reason
(`ListFieldsSchemaTests`), and a second test fails when that pinned copy's property set drifts
from this repo. So a property added here alone turns `@client` red the next time the two are
checked out together, which is the intent: say in the change what the Configurator does with it.

## The expression catalogue mirror

`@client`'s `ExpressionCatalog` (`Utils/Expressions/ExpressionCatalog.cs`) is THE whitelist for a tag
`itemName`, a list column and an `&ref`. Every aircraft key is mirrored THREE times here, as a `const` or
`enum` member in `expressions.schema.json`, `labels.schema.json` and `lists.schema.json`, and
`SystemsSchemaDriftTests` does not check enums. `SchemaVocabularyDriftTests` checks that each aircraft key
is offered by all three, each `session` key by `expressions.schema.json`, and each click action by the
schemas that take one (`EveryAircraftExpression_IsOfferedByTheSchema`,
`EverySessionExpression_IsOfferedByTheExpressionsSchema`, `EveryClickAction_IsOfferedByTheSchema`). It does
not check the reverse direction for keys, nor the `area` and `net` keys, so check those by set difference,
not by eye: collect every `enum` member and `const` string in each file and subtract the catalogue's
`Add("...")` names; the result must be empty. Two groups are the exceptions to "all three". The `session`
keys: only a map item's `showWhen` reads them, never a label or a list, so they are in
`expressions.schema.json` alone, where an expression a `showWhen` names is written. The `area` and `net`
keys: only an `area` or `net` list's row reads them, so they are in `lists.schema.json` and
`expressions.schema.json` and not in `labels.schema.json`.

## datasets/path-rules.schema.json

The vAcc's pathRules override document (`pathRules.json` in a package environment, carried in
`server-dataset.json` under `pathRules`): one definition per row of `@server/internal/pathrules` (`rows`), with its
unit, range and integer-ness (one row, monitorRaisesTimingState, a boolean), the three rows a runway may set in `airports` and `runways`, and the 28 settable rows in
`rules`; the three leg picker rows are absent on purpose. Two copies of one vocabulary: a row added, renamed or
re-ranged in the server's table is changed here and in `@cli/src/definitions/path-rules.schema.json` (a
copy, held equal as JSON by `@cli`'s `path-rules.test.ts` when both are checked out). The cross-row bounds depend on the
deployment's own values and stay the server's check. Not a package file: the client never reads it.

## datasets/runway-preferences.schema.json

The vAcc's runway preferences (`runwayPreferences.json` in a package environment, carried in
`server-dataset.json` under `runwayPreferences`): per airport, its IANA zone and its configurations in
order, each `fixed` (one runway set) or `alternates` (a cycle of runway sets from an epoch), with an
optional `when` whose keys are the rows of `@server/internal/runwayprefs`' condition table. Two copies of one
vocabulary: a condition added, renamed or re-ranged in the server's table is changed here and in
`@cli/src/definitions/runway-preferences.schema.json` (a copy, held equal as JSON by `@cli`'s
`runway-preferences.test.ts` when both are checked out). A name repeated within an airport, a zone that
does not load, a `localTime` whose `from` equals its `to` and an epoch that is no real date stay the
server's check. Not a package file: the client never reads it.

## data/holds.schema.json and data/altimetry.schema.json

The vAcc's reference data: `data/holds.geojson` and `data/altimetry.json` in the vAcc's sector
source (`@sectorsrc`), beside `topsky/` and `euroscope_data/`. Not package files: the client never
reads them from a package. `@cli`'s `convert` checks them against copies in
`@cli/src/definitions/` (held equal as JSON by `@cli`'s `reference-data.test.ts` when both are
checked out), plus the cross-references a schema cannot express (ids and names unique, a table or
hold named exists, band bounds rising), and carries them in `server-dataset.json` under `holds`
and `altimetry`; `@server` serves them. The holds are GeoJSON (RFC 7946, WGS84 longitude and
latitude, not the packages' EPSG:3857) with AIXM 5.1 `HoldingPattern` names; altimetry is plain
JSON. Every file and every `altimetry.json` section is optional, and each file names its sources.
A field changed here is changed in the `@cli` copy, the `@cli` importers (`import-ukcp`,
`import-topsky-altimetry`) and the `@server` reader together.

## What has no schema

`datasets/atc-data.json` and `server-dataset.json` have none. The per-volume
`departureAirports` / `arrivalAirports` / `guests` filters and the per-border-line
`displaySectorLines` rules that `@cli` now emits are described only by
`@cli/src/definitions/package-atc-data.ts` and consumed by `@client/Package/AtcData.cs` and
`@server/internal/importvacc`. Adding a schema for them is a widening; wiring `@cli` to validate
against it is the open loop noted in `@cli`'s CLAUDE.md.

**Authors validate against raw `main`, not your branch.** A schema sitting correct on a feature
branch is invisible to every sector file until it merges, and the symptom is "the client accepts
this but my editor says it is invalid".

## The one rule

There is no schema versioning and no pinned ref, so a merge to `main` is instantly live for
every sector-file author. A schema change IS a package-format change: it needs the matching
`@cli` change, the matching `@client` parser change, and a written rollout path for existing
sector files. Widening (a new optional property) is safe. Narrowing, renaming, or making a
property required breaks live authors and must never land alone.

<!-- shared:writing-rules -->
## Writing rules

These hold for code, comments, docs, UI copy and commit messages in every repo; the hook in
`.claude/hooks/style-check.sh` flags the first four on each edit.
- UK English.
- No em dashes anywhere. Use a period, semicolon, colon or middot.
- C#: explicit types, never `var`.
- A comment says only what the code cannot, in at most two lines. It never restates the code, narrates
  history or explains a mechanism in prose; if it needs more room, the name is wrong.
- A comment never cites a roadmap, phase, wave, track, card, backlog, plan or decision id (`P8`, `Wave 3`,
  `C1-D7`, `B110`, `G-TOOL-04`). It states what the code does in terms that stay true once the plan is
  done; where a pointer helps, it names a test or a method.
- Names carry the meaning: a loop or action is verb first, data is a noun, an event is past tense.
- A comment MAY state a thread, a lock or gate, a unit, a sentinel or an ordering, and must be true: re-read the
  code before writing or keeping one.
This block is identical in all six repos.
<!-- /shared:writing-rules -->
