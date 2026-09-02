---
name: cross-repo-contract-change
description: Land one contract change in lockstep across the five NeoRadar repos (@client, @server, @hub, @cli, @schemas) in the right order. Use when the user says "keep the repos in lockstep", "what else has to change", "I only have the server checkout", "cross-repo change", "which repos does this touch", "the sibling repo is missing", "mirror this on the client", or is changing a session frame, a panel route, the server-dataset artifact or a package schema from inside one repo. Covers the repo id registry, the two lockstep pairs, which repos actually move for which lane, the order, and the per-repo verify command.
---

> **Shared skill.** Copied verbatim into `@client`, `@server`, `@hub`, `@cli`, `@schemas`. Editing one copy alone is a break, not a cleanup.
# One contract change, five repos

Four separate contracts run between these repos, and each one has a different blast radius. Pick the lane first, then work the order. Use `@id` tokens, never absolute paths.

Comment style for any code you touch: the target repo's own `CLAUDE.md`, not this one. The heading
is not named the same in each (`@client` § Code style and comments, `@server` § Style, `@hub` and
`@cli` state it inline), so read the file rather than jumping to a section.

## 1 · The registry is data, not guesswork

Every repo carries an identical `neoradar.repos.json` at its root. It declares `self`, the five repo ids with remotes and `defaultSubpaths`, the data-root ids, and `lockstepPairs`.

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
| **A · Session wire** | the WebSocket session at `/v1/session` — frames, payload DTOs, features, error codes, enums | `@server` + `@client` always. `@hub` only if you touched a type the panel plane also serves. |
| **B · Panel plane** | the server's `/v1/panel/*` REST routes | `@server` + `@hub`. `@client` only if the type is shared with lane A. |
| **C · Dataset artifact** | `server-dataset.json`, `format: "neoradar-server-dataset"`, `formatVersion: 1` | `@cli` (producer) + `@server` (consumer). `@hub` if the review or diff UI shows the new field. |
| **D · Package file format** | package / profile / system files on disk | `@cli` (writer) + `@client` (reader) + `@schemas` (the published schema). |

**All five almost never move for one change.** Say which lane you are in before editing anything.

## 3 · The two lockstep pairs

Straight from `lockstepPairs` in the registry, and these are hard pairs, not conventions:

```
@server/internal/contract/                  ↔  @client/src/NeoRadar.Core/ServerLink/Contract/
@server/internal/contract/testdata/*.json   ↔  @client/tests/NeoRadar.Core.Tests/ServerLink/Vectors/*.json
```

The 26 vector files are byte-identical LF on both sides, and `diff -r` between the two directories must report only `vectors.sha256` (client-side only). A one-sided edit is a contract break.

Third copy to remember, NOT in `lockstepPairs`: `@hub/src/lib/panel/types.ts` hand-mirrors the panel wire in TypeScript. It is a real third transcription of some lane-A types — `contract.AirportConfig` is reused by `@server/internal/api/admin.go`, so `AirportConfig` exists in Go, in C# as `AirportConfigDto`, and in TS as `AirportConfig`. Identifier names differ across all three; **the JSON key is the contract.**

## 4 · Order of operations

`@server` is the system of record for lanes A, B and C. Move it first so there is one authority to mirror.

### Lane A · session wire

1. **`@server`** — struct + `,omitempty`, `envelope.go` const, `vocabulary.go` (`AllFrameTypes` / `allEnumVocabularies`), `internal/api/session.go` handler or `writeFrame` call, `internal/api/errors.go` for a new code, vector in `internal/contract/testdata/`, test in `golden_test.go` or `session_test.go`.
2. Regenerate the vocabulary manifest and commit it:
   `go test ./internal/contract -run TestVocabularyManifestIsCurrent -update-vocabulary`
   `TestVocabularyManifestIsCurrent` fails the build while `vocabulary.json` is stale.
3. **`@client`** — mirror the DTO, register **every** new type on `ServerContractJsonContext` (source-gen only, no reflection fallback), dispatch or send it, copy the vector in **identical bytes**, add the C# assertion. Full procedure and the traps are in the `serverlink-wire-change` skill; do not improvise the client half from this file.
4. **`@client`** — refresh the hash manifest: `pwsh .github/scripts/check-golden-vectors.ps1 -Update`, then re-run it with no switch.
5. **`@hub`** — only if the type also appears on a `/v1/panel` route. Update `@hub/src/lib/panel/types.ts` and whatever renders it.
6. Read the regenerated `vocabulary.json` by eye against the client's `FrameTypes`, `ServerFeatures` and `SessionErrorCodes`. Nothing on the C# side reads that manifest, so this comparison is manual.

### Lane B · panel plane

1. **`@server`** — route + handler + test under `internal/api/panel*.go`. Authz is enforced here and only here.
2. **`@hub`** — `@hub/src/lib/panel/types.ts`, then the fetcher in `@hub/src/lib/panel/`, then the SWR hook in `@hub/src/lib/panel/hooks.ts`, then the page. Never raw `fetch('/api/...')` in a page; the hub is presentation and `usePermissions()` is a UX mirror only.
3. If the type is shared with lane A, you are also in lane A. Go do steps 3 to 6 above.

### Lane C · dataset artifact

1. **`@cli`** — `@cli/src/helper/server-dataset.ts` builds the envelope. Note the artifact splices pre-stringified sections in verbatim so the embedded bytes are exactly the ones hashed (`atcDataSha256` / `nseSha256`); keep that property.
2. **`@server`** — `internal/importvacc/import.go` rejects anything that is not `format == "neoradar-server-dataset"` with `formatVersion == 1`, and `internal/api/panel_dataset.go` re-checks it on upload. Changing `formatVersion` breaks every artifact already staged, so add fields instead.
3. **`@hub`** — only if the staged-review or diff UI must show the new field.

### Lane D · package file format

1. **`@cli`** — the writer.
2. **`@client`** — the reader, under `src/NeoRadar.Core/Package/`.
3. **`@schemas`** — update `package/manifest.schema.json`, `profile.schema.json` or `systems/*.schema.json`. No source file in `@client` or `@cli` references these schemas by path, so nothing fails if you forget; that is exactly why it needs to be on the checklist.

## 5 · Verify, per repo

| Repo | Command |
|---|---|
| `@server` | `go test ./internal/contract/ ./internal/api/` |
| `@client` | `dotnet test tests/NeoRadar.Core.Tests/NeoRadar.Core.Tests.csproj --filter "FullyQualifiedName~ServerLink"` and `pwsh .github/scripts/check-golden-vectors.ps1` |
| `@hub` | `pnpm typecheck` then `pnpm test` |
| `@cli` | `npm run typecheck` then `npm test` |
| `@schemas` | no test suite; validate a real file against the edited schema by hand |

Cross-repo check, only possible when both resolve:

```bash
diff -r @server/internal/contract/testdata @client/tests/NeoRadar.Core.Tests/ServerLink/Vectors
# expected output: "Only in ...Vectors: vectors.sha256" and nothing else
```

The `@client` hash gate compares against its own committed manifest, not against `@server`, so **passing it does not prove the repos agree.** Run the diff.

## 6 · Traps

- **Vector line endings.** `@client` pins the vectors `text eol=lf` in `.gitattributes`; `@server` has no `.gitattributes` and relies on repo-local `core.autocrlf=false`. A CR byte is a hard failure in the gate. Never reformat a vector, never re-indent one, never let an editor add or strip a trailing newline.
- **The manifest and the vectors are two artifacts.** Editing a vector without `-Update` fails the gate; running `-Update` without mirroring the byte change in `@server` silently breaks the pair.
- **Adding a Go const without listing it** in `AllFrameTypes` / `AllFeatures` / `apiErrorCodes` fails a `go/ast`-based completeness test, not the code that uses it. Read the test failure; it names the constant.
- **A feature name the client never declares reads as unsupported and fails silently.** `Supports` takes a raw string. Adding a feature constant is not the same as wiring a gate.
- **Closed enums reject unknown values**, so a new member on a closed enum is a breaking change for older peers even though it looks additive. Open enums degrade to `unknown`.
- **`@hub` is presentation.** Every mutation is re-checked server-side; do not move a rule into the hub to make a screen work.
- **Do not commit.** Leave everything in the working tree in every repo, and never open a PR or push.
