---
name: package-config-field
description: Add or change a field in the NeoRadar package format end to end. Use when the user says add a config field, new mapstyle property, new targets property, new tag item property, extend the manifest, new option for a list column, why is my package field ignored, why did the Configurator delete my field, why is the field red in my editor, or asks how a schema change reaches sector-file authors. Covers the schema-first ordering across @schemas @cli and @client, the parser plus writer round-trip rule that stops a field being silently dropped, the Configurator section wiring, the YAML write-back refusal that blocks mapstyle and lists today, and the mandatory rollout path for sector files that predate the field.
---

> **Shared skill.** Copied verbatim into `@client`, `@cli`, `@schemas`. Editing one copy alone is a break, not a cleanup.
# Adding a package config field, end to end

A package config field is not one edit. It exists in up to five places and a field present in
only some of them fails **silently**: no error, no log, the value simply disappears. This skill
is the ordering and the verification.

Cross-repo ordering, repo id resolution and the lockstep pairs are the
`cross-repo-contract-change` skill's job. Read that first if you do not have all the checkouts.
This skill is the field-level procedure inside that order.

Comment style: root `CLAUDE.md` § Code style and comments.

---

## 1 · Locate the field: which file owns it?

The legs you must edit depend entirely on **which package file** the field lives in. Get this
wrong and you will hunt for a CLI emitter that does not exist.

| File | Schema | CLI emitter | Client parser | Configurator writer |
|---|---|---|---|---|
| `systems/<id>/targets.{json,yaml}` | `@schemas/systems/targets.schema.json` | **none** | `@client/src/NeoRadar.Core/Package/TargetConfig.cs` | `SystemConfigWriter.WriteTargets` |
| `systems/<id>/labels.{json,yaml}` | `@schemas/systems/labels.schema.json` | **none** | `Package/LabelsConfig.cs` | `SystemConfigWriter.WriteLabels` |
| `systems/<id>/mapstyle.{json,yaml}` | `@schemas/systems/mapstyle.schema.json` | **none** | `Package/MapStyleParser.cs` (hand-written) | `SystemConfigWriter.WriteMapStyle` via `MapStyleSerializer` |
| `systems/expressions.{json,yaml}` | `@schemas/systems/expressions.schema.json` | **none** | `Package/ExpressionsConfig.cs` | `ExpressionsConfigWriter.Write` |
| `systems/lists.{json,yaml}` | `@schemas/systems/lists.schema.json` | **none** | `Package/ListsConfig.cs` | `ListsConfigWriter.Write` |
| `manifest.json` | `@schemas/package/manifest.schema.json` | `@cli/src/commands/init-package.ts:129-159`, `@cli/src/commands/indexer.ts:167-200` | `Package/PackageManifest.cs` | none (manifest has no section) |
| `profiles/*.stp` | `@schemas/profile.schema.json` | `@cli/src/commands/converter/asr.ts:168-171` | `Package/Profile.cs` | `ProfileStorageService` |
| `datasets/atc-data.json` | none | `@cli/src/commands/converter/atc-data-parser.ts:193` | `Package/AtcData.cs` | none |
| `datasets/nse.json` | none | `@cli/src/helper/nse.ts` | `Package/EseDataset.cs` | none |
| `server-dataset.json` | none | `@cli/src/helper/server-dataset.ts` | not read by the client | none |

**The `systems/*` configs have no CLI leg.** `@cli/src/commands/init-package.ts:18-75` downloads
the whole starter tree from the `neoradar-project/base-package` release and unzips it; the CLI
never generates or rewrites a systems config, and it never writes a `$schema` key anywhere
(`grep -rn '\$schema' @cli/src` returns nothing). A new systems-config field therefore lands in
`@schemas` + `@client` + optionally the base-package template, and the "emitter" step is a no-op.

`TagItem` is the shared shape used by both tag grids and list columns
(`@client/src/NeoRadar.Core/Package/LabelsConfig.cs:10`), so a `TagItem` field appears in the
labels schema **and** the lists schema and reaches two Configurator sections.

---

## 2 · The order, and why it is not negotiable

`@schemas` has no versioning and no pinned ref: sector files reference the raw URL on `main`,
so a merge is instantly live for every author. Verified in the real sector files —
`@sectorsrc/UK-Sector-File/package/systems/*/targets.json:2` uses
`.../schemas/refs/heads/main/systems/targets.schema.json`, and the YAML siblings use a
`# yaml-language-server: $schema=.../schemas/main/systems/mapstyle.schema.json` first line.

Every root schema except `lists` sets **`additionalProperties: false`**:

```
$ python -c "import json,glob; [print(f, json.load(open(f,encoding='utf-8')).get('additionalProperties','ABSENT')) for f in glob.glob('systems/*.json')]"
systems\expressions.schema.json False
systems\labels.schema.json      False
systems\lists.schema.json       ABSENT
systems\mapstyle.schema.json    False
systems\targets.schema.json     False
```

So an author who writes the new field **before** the schema lands sees a red editor error. The
schema edit is not documentation, it is the permission to use the field.

Order:

1. **`@schemas`** — add the property as **optional**. Widening is safe. Do not add it to
   `required`; do not narrow or rename an existing property.
2. **`@client` parser** — accept it, with the absent case producing the documented default.
3. **`@client` writer** — round-trip it. See §4; skipping this deletes author data.
4. **`@client` Configurator section** — expose it (optional, but a field with no UI is a field
   nobody uses).
5. **`@cli`** — only if §1 says there is an emitter for that file.
6. **Rollout note** — §6. Mandatory, not optional.

---

## 3 · The client parser leg

Two parser families, and they behave differently.

### Source-generated (targets, labels, expressions, lists, manifest, profile)

Add the property with an explicit `[JsonPropertyName]` matching the schema's camelCase key.
Nullable, or a value type with the default that means "absent":

```csharp
[JsonPropertyName("historyTrailsSkipSteps")]
public int HistoryTrailsSkipSteps { get; set; }
```

Reads go through `FileParseHelper.ReadJsonOrYaml` (`Package/FileParseHelper.cs:12-27`), which
tries `.json`, `.yaml`, `.yml` in that order and routes YAML through the reflection-free
`YamlToJson`. You get YAML support for free; you do not get YAML **write** support (§5).

The `JsonSerializerContext`s are in `@client/src/NeoRadar.Core/Json/CoreJsonContexts.cs`.
Adding a **property** to an already-registered type needs no context edit. Adding a new **type**
needs a `[JsonSerializable]` on `CoreReadJsonContext` (`:19-34`) and, if it is written,
`CoreWriteJsonContext` (`:40-48`). Both contexts are `internal`, so a desktop-side section can
never serialise a config itself — that is why all writes go through the Core writer interfaces.

Validation is `DataAnnotations` via `PackageValidator` (`Package/PackageValidator.cs`). Note the
asymmetry, it matters for rollout:

- `Validate<T>` **warns and continues** (`:17-27`) — an invalid object still loads.
- `ValidateList<T>` **drops the invalid element** (`:31-41`) — so adding `[Required]` to a
  `DynamicListConfig` or `TagItem` field silently removes whole entries from every package that
  predates the field. Never retro-fit `[Required]`.

### Hand-written (mapstyle only)

`SystemMapStyle` uses tuples and is parsed by `MapStyleParser.Parse`
(`Package/MapStyleParser.cs:9-47`) and serialised by `MapStyleSerializer.Serialize`
(`Package/MapStyleSerializer.cs:19-56`). A mapstyle field is **four** edits, not two: the
`AtmSystem.cs` property, the parser `TryGetProperty` line, the serialiser `Write*` line, and the
schema. Miss the serialiser and §4 bites.

---

## 4 · The writer leg: a field the writer skips is deleted

**No config type in Core has `[JsonExtensionData]`** — verified,
`grep -rn JsonExtensionData src/NeoRadar.Core --include=*.cs` returns nothing. Combined with
`MapStyleSerializer` writing only the fields it knows about, the consequence is:

> Any property present on disk but absent from the client model is **silently erased** the first
> time a user saves that file in the Configurator.

That is a data-loss bug against a real author's package, not a cosmetic gap. It is why the rule
is parser **and** writer in the same change, and why the client leg is three files, not one:
parser (§3), writer (this section), Configurator section view model (§7).

All writes route through `Package/Writers/`:
`ISystemConfigWriter`, `IExpressionsConfigWriter`, `IListsConfigWriter`, `ISystemFolderWriter`,
`IProfileStorageService` — singletons registered at
`@client/src/NeoRadar/Program.cs:280-284`. Every one of them writes through
`AtomicConfigWriter.Write` (tmp file + `File.Move` overwrite,
`Package/Writers/AtomicConfigWriter.cs:8-26`). Never `File.WriteAllText` a package file from a
section.

If the field has a structural invariant, add it to that writer's validation list so the write
fails before touching disk — `SystemConfigWriter.ValidateTargets` is the model
(`Package/Writers/SystemConfigWriter.cs:90-103`), and its failure path returns
`ConfigWriteResult.Fail` and writes nothing.

### Round-trip test (required)

Extend `@client/tests/NeoRadar.Core.Tests/Package/ConfigWriterTests.cs`. It already holds 19
facts in this exact shape: parse a JSON literal, write, re-parse from disk, assert the field
survived. Name the test after what it protects.

```
dotnet test tests/NeoRadar.Core.Tests/NeoRadar.Core.Tests.csproj --filter ConfigWriterTests
```

For mapstyle, follow `WriteMapStyle_RoundTripsThroughParser` (`:333`) — parser and serialiser
must agree, and only a round-trip catches a one-sided edit.

---

## 5 · YAML write-back is refused, and both real sector files are YAML

Every writer resolves the on-disk extension through `ConfigPathResolver.Resolve`
(`Package/Writers/ConfigPathResolver.cs:15-24`) and **fails** if it is `.yaml`/`.yml`:

```csharp
if (resolved.IsYaml)
    return ConfigWriteResult.Fail("This system's mapstyle config is YAML; YAML write-back is not supported yet.");
```

This is not hypothetical. Checked against the two real sector files:

```
$ ls @sectorsrc/UK-Sector-File/package/systems/default
labels.json  mapstyle.yaml  targets.json
$ ls @sectorsrc/UK-Sector-File/package/systems
default  expressions.json  gatwick-smr  lgw  lhr  lists.yaml  sco  smr  stc
```

`@sectorsrc/LFXX-Sector-File` is identical in shape: `mapstyle.yaml` per system, `lists.yaml` at
the root. So **today, a new mapstyle or lists field cannot be edited in the Configurator for
either shipping sector file** — the save refuses with the message above. Targets, labels and
expressions are JSON and do save.

Plan for this up front. A mapstyle field is author-edits-YAML-by-hand until YAML write-back
exists, and the Configurator UI for it should not pretend otherwise.

---

## 6 · Rollout path for sector files that predate the field

Required in the change description. Fill in all five lines; "n/a" is a valid answer but silence
is not.

1. **Absent-field behaviour.** What does a package without the field do? Name the default and
   where it comes from (a property initialiser, or the parser's untouched default). It must be
   the pre-change behaviour, exactly.
2. **Editor impact.** The schema edit is live on `main` the moment it merges. Confirm the
   property is optional and not in `required`, so no existing file starts erroring.
3. **Author action.** Nothing (widening), or a documented manual edit. If the file is
   `mapstyle.yaml`/`lists.yaml`, say so explicitly per §5 — the Configurator is not the path.
4. **Re-convert needed?** Only if §1 shows a CLI emitter for that file. Systems configs never
   need a re-convert; a manifest or `.stp` field usually does (`neoradar-cli convert`).
5. **Write-back safety.** State that the writer round-trips the field, and that the round-trip
   test exists and is named. This is the line that certifies no author data is erased.

Cross-check: `@sectorsrc/UK-Sector-File` and `@sectorsrc/LFXX-Sector-File` are the two live
consumers. If a claim in your rollout note is not true of both of them, it is not true.

---

## 7 · The Configurator section leg

Sections live in `@client/src/NeoRadar/Screens/Configurator/Sections/`. They are **hand
constructed** in `ConfiguratorViewModel.BuildSections()`
(`Screens/Configurator/ConfiguratorViewModel.cs:130`), not resolved from DI — only the shell
VM itself is registered (`Program.cs:276`). Adding a constructor dependency to a section means
editing `BuildSections`.

Two shell contracts:

| Contract | File | Obligation |
|---|---|---|
| `IConfiguratorSaveable` | `Screens/Configurator/IConfiguratorSaveable.cs:10-17` | `IsDirty`, `DirtyChanged`, `TrySave()`. Without it the footer cannot save the section. |
| `IConfiguratorScopedSection` | `Screens/Configurator/IConfiguratorScopedSection.cs:7-10` | `SetSystem(AtmSystem?)`. System-scoped sections re-read on every switch; never cache the system. |

`TargetsSectionViewModel` is the reference implementation. The pattern for one new field:

1. An `[ObservableProperty]` for the editable value.
2. Its `nameof(...)` added to the section's edit-field set so a change marks dirty —
   `Sections/TargetsSectionViewModel.cs:37-42` (`s_editFields`).
3. Read it in `SetSystem` / the section's reload path from the parsed config object.
4. Write it back onto the config model before `TrySave` calls the writer —
   `Sections/TargetsSectionViewModel.cs:435-452`.
5. The XAML row. Do not put a `LineHeight`, `Padding` or `Height` on the control by feel; see
   the `ui-text-metrics` skill.

`TrySave` must surface failure rather than swallowing it: set `SaveFailed` + `SaveStatus` from
`ConfigWriteResult.Errors` and return `false`, exactly as `TargetsSectionViewModel.cs:435-452`
does. Silent success on a refused write is the worst outcome, because the author believes the
edit landed.

---

## 8 · Checklist

- [ ] Owning file identified in §1, and the CLI leg confirmed to exist or not exist.
- [ ] Schema property added as optional, not in `required`, no narrowing or rename.
- [ ] Parser accepts it; absent means the documented pre-change default.
- [ ] For mapstyle: `AtmSystem` property + `MapStyleParser` + `MapStyleSerializer` all four edited.
- [ ] Writer round-trips it. No `[Required]` retro-fitted to any list-element type.
- [ ] Round-trip test added to `ConfigWriterTests` and named after what it protects; suite green.
- [ ] New serialisable **type** registered in both `CoreJsonContexts` contexts (new property only, no edit).
- [ ] Configurator section reads it, marks dirty, writes it back, and reports write failure.
- [ ] YAML refusal accounted for if the field lives in mapstyle or lists.
- [ ] Rollout path written, all five lines, checked against both live sector files.
