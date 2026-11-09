---
name: cross-repo-contract-change
description: Land one contract change in lockstep across @client, @server, @hub, @cli and @schemas. Use for "keep the repos in lockstep", "which repos does this touch", "what else has to change", "I only have the server checkout", "the sibling repo is missing", "mirror this on the client", or a session frame, panel route, server-dataset or package schema change made from one repo.
---

> **Shared skill.** Copied verbatim into `@client`, `@server`, `@hub`, `@cli`, `@schemas`. Editing one copy alone is a break, not a cleanup.
# One contract change, five repos

Four separate contracts run between these repos, and each one has a different blast radius. Pick the lane first, then work the order. Use `@id` tokens, never absolute paths.

Comment style for any code you touch: the target repo's own `CLAUDE.md`, not this one. The heading
is not named the same in each (`@client` § Writing rules and `.claude/rules/csharp-style.md`, `@server` `CLAUDE.md` § Go style, `@hub` and
`@cli` state it inline), so read the file rather than jumping to a section.

## 1 · The registry is data, not guesswork

Every repo carries an identical `neoradar.repos.json` at its root. It declares `self`, the six repo ids with remotes and `defaultSubpaths` (the five below plus `@pluginsdk`, which none of these contracts reach), the data-root ids, and `lockstepPairs`.

| id | Repo | Language |
|---|---|---|
| `@client` | `client-sharp` | C# / Avalonia radar client |
| `@server` | `neoradar-server` | Go compute tier |
| `@hub` | `neoradar-hub` | Next.js management panel |
| `@cli` | `cli` | TypeScript package + dataset build pipeline |
| `@schemas` | `schemas` | Shared JSON Schemas for package / profile / system files |

Resolution order, from the registry's own `resolution.order`: `NEORADAR_<ID>_DIR` env var, then `neoradar.repos.local.json` (gitignored, per-machine), then an upward scan trying each `defaultSubpaths` entry. Its two rules are binding:

- **Never guess a path.** If an id does not resolve, say so and work from your own repo alone.
- **A sibling repo is normally ABSENT in CI.** That is the expected case, not an error.

So when only one checkout exists: do your half in full, then write the other half out as an explicit edit list (files, symbols, exact JSON bytes for any vector) and hand it over. Do not half-land a wire change and hope.

## 2 · Pick the lane

| Lane | Contract surface | Repos that move |
|---|---|---|
| **A · Session wire** | the WebSocket session at `/v1/session`: frames, payload DTOs, features, error codes, enums | `@server` + `@client` always. `@hub` only if you touched a type the panel plane also serves. |
| **B · Panel plane** | the server's `/v1/panel/*` REST routes | `@server` + `@hub`. `@client` only if the type is shared with lane A. |
| **C · Dataset artifact** | `server-dataset.json`, `format: "neoradar-server-dataset"`, `formatVersion: 1` | `@cli` (producer) + `@server` (consumer). `@hub` if the review or diff UI shows the new field. |
| **D · Package file format** | package / profile / system files on disk | `@cli` (writer) + `@client` (reader) + `@schemas` (the published schema). |

**All five almost never move for one change.** Say which lane you are in before editing anything.

## 3 · The four lockstep pairs

Straight from `lockstepPairs` in the registry, and these are hard pairs, not conventions:

```
@server/internal/contract/                  ↔  @client/src/NeoRadar.Core/ServerLink/Contract/
@server/internal/contract/testdata/*.json   ↔  @client/tests/NeoRadar.Core.Tests/ServerLink/Vectors/*.json
@server/internal/contract/vocabulary.json   ↔  @client/tests/NeoRadar.Core.Tests/ServerLink/vocabulary.json
@server/internal/trajectory/testdata/copx-matcher-cases.json  ↔  @client/tests/NeoRadar.Core.Tests/FutureOwnership/Copx/copx-matcher-cases.json
```

The 42 vector files are byte-identical LF on both sides, and `diff -r` between the two directories must report only `vectors.sha256` (client-side only). The vocabulary copy sits outside `Vectors/`, so that `diff -r` never sees it; check it with its own `diff`. A one-sided edit is a contract break.

Third copy to remember, NOT in `lockstepPairs`: `@hub/src/lib/panel/types.ts` hand-mirrors the panel wire in TypeScript. It is a real third transcription of some lane-A types; `contract.AirportConfig` is reused by `@server/internal/vaccconfig/http_airports.go`, so `AirportConfig` exists in Go and in TS as `AirportConfig`; the C# `AirportConfigDto` left with the session wire's `airports` in contract 9. Identifier names differ across all three; **the JSON key is the contract.**

## 4 · Order of operations

`@server` is the system of record for lanes A, B and C. Move it first so there is one authority to mirror.

### Lane A · session wire

1. **`@server`**: struct + `,omitempty`, `envelope.go` const, `vocabulary.go` (`AllFrameTypes` / `allEnumVocabularies`; a feature goes in `AllFeatures`, `capabilities.go`), then for an uplink frame one row in the handler table (`newFrameHandlers` in `internal/session/session.go`, through `on` / `onFlightRecord` / `onRaw` from `frame_handlers.go`) or for a downlink frame a `writeFrame` call (`internal/session/session_socket.go`), and either way a row in `frameWiring` (`internal/servertest/frame_wiring_test.go`), `internal/errcode/errcode.go` plus `apiErrorCodes` (`internal/contract/vocabulary_test.go`) for a new code, vector in `internal/contract/testdata/`, test in `golden_test.go` or `session_test.go`.
2. Regenerate the vocabulary manifest and commit it:
   `go test ./internal/contract -run TestVocabularyManifestIsCurrent -update-vocabulary`
   `TestVocabularyManifestIsCurrent` fails the build while `vocabulary.json` is stale.
3. **`@client`**: mirror the DTO, register **every** new type on `ServerContractJsonContext` (source-gen only, no reflection fallback), dispatch or send it, copy the vector in **identical bytes**, add the C# assertion. Full procedure and the traps are in the `serverlink-wire-change` skill; do not improvise the client half from this file.
4. **`@client`**: copy the regenerated `@server/internal/contract/vocabulary.json` byte for byte to `@client/tests/NeoRadar.Core.Tests/ServerLink/vocabulary.json`, then refresh the hash manifest: `pwsh .github/scripts/check-golden-vectors.ps1 -Update`, then re-run it with no switch. The manifest hashes the 42 vectors plus a 43rd line for `../vocabulary.json`, so a mirrored copy without `-Update` fails the gate.
5. **`@hub`**: only if the type also appears on a `/v1/panel` route. Update `@hub/src/lib/panel/types.ts` and whatever renders it.
6. Run `WireVocabularyManifestTests` on the client. It reads the committed copy and checks the contract version, features, frame types, declared error codes, enum members and enum openness against the C# side, so no part of this is by eye. Only `CommittedManifest_IsByteIdenticalToTheServerRepoCopy` may skip, and only when `@server` does not resolve.

### Lane B · panel plane

1. **`@server`**: route + handler in the owning feature's `Mount` (its `http*.go`, e.g. `internal/panel/http.go`, `internal/vaccconfig/http_airports.go`), registered through the `internal/httpapi` `Router` method for its guard tier (`PanelViewer`, `PanelEditor`, `PanelOwner`, `PanelGlobalAdmin`, ...); `internal/api/routes.go` is the one list of mounted features and holds no handler. Tests go in `internal/servertest/panel*_test.go`, and every route is a line of `internal/servertest/testdata/routes.golden.txt` (`TestRouteInventory_ComposedServer_MatchesTheGolden`). Authz is enforced here and only here.
2. **`@hub`**: `@hub/src/lib/panel/types.ts`, then the fetcher in `@hub/src/lib/panel/`, then the SWR hook in `@hub/src/lib/panel/hooks.ts`, then the page. Never raw `fetch('/api/...')` in a page; the hub is presentation and `usePermissions()` is a UX mirror only.
3. If the type is shared with lane A, you are also in lane A. Go do steps 3 to 6 above.

### Lane C · dataset artifact

1. **`@cli`**: `@cli/src/helper/server-dataset.ts` builds the envelope. Note the artifact splices pre-stringified sections in verbatim so the embedded bytes are exactly the ones hashed (`atcDataSha256` / `nseSha256`); keep that property.
2. **`@server`**: `internal/importvacc/import.go` rejects anything that is not `format == "neoradar-server-dataset"` with `formatVersion == 1`, and `internal/importvacc/http_datasets.go` re-checks it on upload. Changing `formatVersion` breaks every artifact already staged, so add fields instead.
3. **`@hub`**: only if the staged-review or diff UI must show the new field.

### Lane D · package file format

1. **`@cli`**: the writer.
2. **`@client`**: the reader, under `src/NeoRadar.Core/Package/`.
3. **`@schemas`**: update `package/manifest.schema.json`, `profile.schema.json`, `systems/*.schema.json` or `datasets/*.schema.json`. Only part of this is tested. `@client`'s `SystemsSchemaDriftTests` and `SchemaVocabularyDriftTests` (`tests/NeoRadar.Core.Tests/Package/`) compare six systems schemas, the profile schema and the zones and radars dataset schemas against the C# models and vocabularies; `LayerHeaderSchemaTests` does the `map-layer` header; and each Configurator `<X>FieldsSchemaTests` (`tests/NeoRadar.Tests/Screens/Configurator/`) holds its declared fields against a schema copy pinned in Fixtures. The `areas`, `cas`, `msaw`, `path-rules` and `stca-runways` dataset schemas have no such test, and `@cli` only writes a `$schema` URL, so there nothing fails if you forget; that is exactly why it needs to be on the checklist.

## 5 · Verify, per repo

| Repo | Command |
|---|---|
| `@server` | `go test ./internal/contract/ ./internal/session/ ./internal/servertest/` (the composed server's tests, panel routes included, live in `servertest`; `internal/api` is the composition root) |
| `@client` | `dotnet test tests/NeoRadar.Core.Tests/NeoRadar.Core.Tests.csproj --filter "FullyQualifiedName~ServerLink"` and `pwsh .github/scripts/check-golden-vectors.ps1` |
| `@hub` | `pnpm typecheck` then `pnpm test` |
| `@cli` | `npm run typecheck` then `npm test` |
| `@schemas` | no test suite; validate a real file against the edited schema by hand |

Cross-repo check, only possible when both resolve:

```bash
diff -r @server/internal/contract/testdata @client/tests/NeoRadar.Core.Tests/ServerLink/Vectors
# expected output: "Only in ...Vectors: vectors.sha256" and nothing else

diff @server/internal/contract/vocabulary.json @client/tests/NeoRadar.Core.Tests/ServerLink/vocabulary.json
# expected output: nothing at all
```

The `@client` hash gate compares against its own committed manifest, not against `@server`, so **passing it does not prove the repos agree.** Run the diff.

## 6 · Traps

- **Vector line endings.** Both repos pin them `text eol=lf` in their own `.gitattributes`: `@client` the `Vectors/*.json` glob, `vectors.sha256` and `vocabulary.json`, `@server` the `internal/contract/testdata/*.json` glob and `internal/contract/vocabulary.json`. A CR byte is a hard failure in the gate. Never reformat a vector, never re-indent one, never let an editor add or strip a trailing newline.
- **The hash manifest, the vectors and the vocabulary copy are three artifacts.** Editing a vector without `-Update` fails the gate; running `-Update` without mirroring the byte change in `@server` silently breaks the pair; regenerating `vocabulary.json` on the server without copying it across leaves `WireVocabularyManifestTests` failing on the client.
- **Adding a Go const without listing it** in `AllFrameTypes` / `AllFeatures` / `apiErrorCodes` fails a `go/ast`-based completeness test, not the code that uses it. Read the test failure; it names the constant.
- **A feature name the client never declares reads as unsupported and fails silently.** `Supports` takes a raw string. Adding a feature constant is not the same as wiring a gate.
- **Closed enums reject unknown values**, so a new member on a closed enum is a breaking change for older peers even though it looks additive. Open enums degrade to `unknown`.
- **`@hub` is presentation.** Every mutation is re-checked server-side; do not move a rule into the hub to make a screen work.
- **Do not commit.** Leave everything in the working tree in every repo, and never open a PR or push.
