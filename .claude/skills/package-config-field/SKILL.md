---
name: package-config-field
description: Add or change a field in the NeoRadar package format end to end. Use when the user says add a config field, new mapstyle property, new targets property, new tag item property, extend the manifest, new option for a list column, why is my package field ignored, why did the Configurator delete my field, why is the field red in my editor, or asks how a schema change reaches sector-file authors. Covers the schema-first ordering across @schemas @cli and @client, the parser plus writer round-trip rule that stops a field being silently dropped, the Configurator section wiring, the YAML write-back refusal that blocks mapstyle today (lists is edited as a document and saves in YAML), and the mandatory rollout path for sector files that predate the field.
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
| `systems/<id>/policy.json` | `@schemas/systems/policy.schema.json` | **none** | `Package/SystemPolicy.cs` plus the owning module's section type | none |
| `systems/shapes.{json,yaml}` | `@schemas/systems/shapes.schema.json` | **none** | `Package/ShapesConfig.cs` | `ShapesConfigWriter.Write` |
| `systems/expressions.{json,yaml}` | `@schemas/systems/expressions.schema.json` | **none** | `Package/ExpressionsConfig.cs` | `ExpressionsConfigWriter.Write` |
| `systems/lists.{json,yaml}` | `@schemas/systems/lists.schema.json` | **none** | `Package/ListsConfig.cs` | `ListsConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `manifest.json` | `@schemas/package/manifest.schema.json` | `initPackage` (`@cli/src/commands/init-package.ts`), `indexer` (`@cli/src/commands/indexer.ts`) | `Package/PackageManifest.cs` | none (manifest has no section) |
| `profiles/*.stp` | `@schemas/profile.schema.json` | `AsrFolderConverter.processFile` (`@cli/src/commands/converter/asr.ts`) | `Package/Profiles/Profile.cs` | `ProfileStorageService` |
| `datasets/atc-data.json` | none | `AtcDataManager.writeAtcData` (`@cli/src/commands/converter/atc-data-parser.ts`) | `Package/AtcData.cs` | none |
| `datasets/nse.json` | none | `@cli/src/helper/nse.ts` | `Package/EseDataset.cs` | none |
| `datasets/zones.geojson` | `@schemas/datasets/zones.schema.json` | **none** (hand-authored) | `Package/ZonesDataset.cs` | none |
| `datasets/radars.json` | `@schemas/datasets/radars.schema.json` | `writeRadarsDataset` (`@cli/src/helper/radars.ts`) | `Package/RadarsDataset.cs` | none |
| `datasets/msaw.geojson` | `@schemas/datasets/msaw.schema.json` | `buildMsawDataset` (`@cli/src/commands/converter/topsky/topsky-msaw.ts`) | `Package/MsawDataset.cs` | none |
| `datasets/areas.geojson` | `@schemas/datasets/areas.schema.json` | `buildAreasDataset` (`.../topsky/topsky-areas.ts`) | not read by the client | none |
| `datasets/stca-runways.json` | `@schemas/datasets/stca-runways.schema.json` | `buildStcaRunwaysDataset` (`.../topsky/topsky-stca.ts`) | not read by the client | none |
| `server-dataset.json` | none | `@cli/src/helper/server-dataset.ts` | not read by the client | none |

`policy.json` is the one systems config with no writer at all: nothing in the Configurator edits it yet, so the §4 erase-on-save hazard does not apply to it and the round-trip test in §8 is the schema drift case instead. Its sections are owned by the modules that consume them (`Correlation/CorrelationPolicySection.cs` is the model), not by `Package/`, so a new section is a property on `SystemPolicy` plus a section type and a `Resolve` beside the module that reads it.

**The `systems/*` configs have no CLI leg.** `downloadBasePackage` (`@cli/src/commands/init-package.ts`)
downloads the whole starter tree from the `neoradar-project/base-package` release and unzips it; the
CLI never generates or rewrites a systems config. The only `$schema` keys it writes are on the four
datasets it emits (`radars`, `msaw`, `areas`, `stca-runways`; `grep -rn '\$schema' @cli/src`), so a
dataset schema that moves needs its constant there moved too. A new systems-config field therefore lands in
`@schemas` + `@client` + optionally the base-package template, and the "emitter" step is a no-op.

`TagItem` is the shared shape used by both tag grids and list columns
(`TagItem` in `@client/src/NeoRadar.Core/Package/LabelsConfig.cs`), so a `TagItem` field appears in the
labels schema **and** the lists schema and reaches two Configurator sections.

---

## 2 · The order, and why it is not negotiable

`@schemas` has no versioning and no pinned ref: sector files reference the raw URL on `main`,
so a merge is instantly live for every author. Verified in the real sector files —
the `$schema` key of `@sectorsrc/UK-Sector-File/package/systems/*/targets.json` uses
`.../schemas/refs/heads/main/systems/targets.schema.json`, and the YAML siblings use a
`# yaml-language-server: $schema=.../schemas/main/systems/mapstyle.schema.json` first line.

Every root schema except `lists` sets **`additionalProperties: false`**:

```
$ python -c "import json,glob; [print(f, json.load(open(f,encoding='utf-8')).get('additionalProperties','ABSENT')) for f in sorted(glob.glob('systems/*.json')+glob.glob('datasets/*.json'))]"
datasets\areas.schema.json        False
datasets\msaw.schema.json         False
datasets\radars.schema.json       False
datasets\stca-runways.schema.json False
datasets\zones.schema.json        False
systems\expressions.schema.json   False
systems\labels.schema.json        False
systems\lists.schema.json         ABSENT
systems\mapstyle.schema.json      False
systems\policy.schema.json        False
systems\shapes.schema.json        False
systems\targets.schema.json       False
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

### Source-generated (targets, labels, expressions, shapes, lists, manifest, profile)

Add the property with an explicit `[JsonPropertyName]` matching the schema's camelCase key.
Nullable, or a value type with the default that means "absent":

```csharp
[JsonPropertyName("historyTrailsSkipSteps")]
public int HistoryTrailsSkipSteps { get; set; }
```

Reads go through `FileParseHelper.ReadJsonOrYaml`, which
tries `.json`, `.yaml`, `.yml` in that order and routes YAML through the reflection-free
`YamlToJson`. You get YAML support for free; you do not get YAML **write** support (§5), except in
`lists`, which the Configurator edits as a document (§4a). One
YAML shape is not a plain string: a literal block (`|`) whose first non-blank line starts with `=`
arrives as the rule array (one line: the string), so a property that takes a rule list is a
`JsonElement?`, never a `string`.

**A property that may be dynamic keeps its `JsonElement?` and gains a parsed form beside it.** The
`JsonElement?` is what the writers round-trip, so it stays the serialised property; behind it sits a
`DynamicProperty` (`Package/DynamicProperty.cs`) whose `Parsed` is the `DynamicValue` the engines
read, parsed on first use and again whenever the property is set:

```csharp
[JsonPropertyName("color")]
public JsonElement? Color { get => _color.Json; set => _color = new DynamicProperty(value); }

private DynamicProperty _color;

[JsonIgnore]
public DynamicValue ParsedColor => _color.Parsed;
```

Read it through `DynamicValueResolver` (the `tag-and-list-authoring` skill lists the readers; the
typed ones take the property's name, for the warning an unreadable entry gets once) and never test
the JSON for a leading `=` or `&` yourself: an inventory test fails a file that does. A field that
is geometry, layout, controller-owned profile state, a safety-net threshold or a click gate stays a
plain typed property and takes no rule at all; add its row to that skill's table either way, with
the reason.

**An `applyWhen` is the same shape with `ConditionProperty`**: the `JsonElement?` stays the
serialised property and `ParsedApplyWhen` is the `Condition` the engines ask. No file in Core or
Rendering outside the two model files reads the JSON
(`ConditionTests.NoFileOutsideTheModels_ReadsAnApplyWhenAsJson`).

The `JsonSerializerContext`s are in `@client/src/NeoRadar.Core/Json/CoreJsonContexts.cs`.
Adding a **property** to an already-registered type needs no context edit. Adding a new **type**
needs a `[JsonSerializable]` on `CoreReadJsonContext` and, if it is written,
`CoreWriteJsonContext`. Both contexts are `internal`; the desktop reaches them (`InternalsVisibleTo`)
only to clone a section's working copy (`ConfiguratorClone`), and every write still goes through the
Core writer interfaces.

Validation is `DataAnnotations` via `PackageValidator` (`Package/PackageValidator.cs`). Note the
asymmetry, it matters for rollout:

- `PackageValidator.Validate<T>` **warns and continues** — an invalid object still loads.
- `PackageValidator.ValidateList<T>` **drops the invalid element** — so adding `[Required]` to a
  `DynamicListConfig` or `TagItem` field silently removes whole entries from every package that
  predates the field. Never retro-fit `[Required]`.

### Hand-written (mapstyle only)

`SystemMapStyle` uses tuples and is parsed by `MapStyleParser.Parse` and serialised by
`MapStyleSerializer.Serialize`. A mapstyle field is **four** edits, not two: the
`AtmSystem.cs` property, the parser `TryGetProperty` line, the serialiser `Write*` line, and the
schema. Miss the serialiser and §4 bites.

---

## 4 · The writer leg: a field the writer skips is deleted

This section is true of every Configurator file **except `lists`**, which no longer has a writer
leg at all: §4a.

**No config type in Core has `[JsonExtensionData]`** — verified,
`grep -rn JsonExtensionData src/NeoRadar.Core --include=*.cs` returns nothing. Combined with
`MapStyleSerializer` writing only the fields it knows about, the consequence is:

> Any property present on disk but absent from the client model is **erased** the first time a
> user saves that file in the Configurator. The save asks once per file first and names the keys it
> would remove (`ConfiguratorFileState.ReformatNotice`), but a confirmed save still removes them.

That is a data-loss bug against a real author's package, not a cosmetic gap. It is why the rule
is parser **and** writer in the same change, and why the client leg is three files, not one:
parser (§3), writer (this section), Configurator section view model (§7).

All writes route through `Package/Writers/`:
`ISystemConfigWriter`, `IExpressionsConfigWriter`, `IListsConfigWriter`, `IShapesConfigWriter`,
`ISystemFolderWriter`, `IProfileStorageService` — singletons registered in
`PackageModule.AddPackageServices`. Every one of them writes through
`AtomicConfigWriter.Write` (tmp file + `File.Move` overwrite). Never `File.WriteAllText` a package file from a
section.

**A save reaches the running views through one path, and it is the on-disk path.** Each writer
tells `IOwnPackageWrites` (implemented by `Package/ReloadPackageFilesOnChange`) what it wrote, through
the member for its file: `SystemFile(path, systemId, geometryAffected)`, `ListsFile`,
`ExpressionsFile`, `ShapesFile`, `ProfileInMemory(profile)` for a stored profile edited in place, and
`Unwatched(path)` for a file whose content the stores already hold. The watcher's echo of that write is ignored, the file is reloaded into the store once,
and the typed `*FileChanged` bus event tells every open radar view, main window and insets alike,
to re-apply what it shows. An edit made in a text editor arrives at the same reload through
`PackageFileWatcher`. A section never publishes a reload event and never pokes a view; a new
writer that skips the `IOwnPackageWrites` call saves correctly and shows nothing until restart. A
new package FILE needs a watcher entry, a `Reload*` on `IPackageLoaderService` and its event as
well (`datasets/msaw.geojson` is the model).

If the field has a structural invariant, add it to that writer's validation list so the write
fails before touching disk — `SystemConfigWriter.ValidateTargets` is the model, and its failure path returns
`ConfigWriteResult.Fail` and writes nothing.

### Round-trip test (required)

Extend `@client/tests/NeoRadar.Core.Tests/Package/ConfigWriterTests.cs`. It already holds 47
facts, most in this exact shape: parse a JSON literal, write, re-parse from disk, assert the field
survived. Name the test after what it protects.

```
dotnet test tests/NeoRadar.Core.Tests/NeoRadar.Core.Tests.csproj --filter ConfigWriterTests
```

For mapstyle, follow `WriteMapStyle_RoundTripsThroughParser` — parser and serialiser
must agree, and only a round-trip catches a one-sided edit.

---

## 4a · Lists is edited as a document: nothing is serialised, so nothing is deleted

`systems/lists.{json,yaml,yml}` is the first file moved onto the document model
(`@client/src/NeoRadar.Core/Package/Documents/`). The Lists section holds the file's own text as a
`PackageDocument` inside a `DocumentDraft`; every change a user makes is one `DocumentEdit` at a
path (`SetValue`, `AddKey`, `Remove`, `InsertElement`, `MoveElement`, `RenameKey`), planned as one
patch of that text and checked by reading the patched text back through the client's own loader.
`ListsConfigWriter.Write(packagePath, document)` reads the document once as the loader will (a
file the client could not load is never written), writes `document.ToBytes()` through
`AtomicConfigWriter` and tells `IOwnPackageWrites.ListsFile`. The typed `DynamicListConfig` is only
ever READ from the document. Consequences for a new lists field:

- **A field the client model does not know survives every save**, with its comments, key order,
  quoting, rule blocks and line endings. There is no erase-on-save hazard and no
  `ReformatNotice` for this file.
- **There is no writer leg and no `ConfigWriterTests` round-trip.** The parser leg (§3) is still
  what makes the client READ the field. What a save writes is pinned by
  `ListsConfigWriterTests` (Core) and, per field, by
  `ListsOneEditOnTheRealFileTests` (desktop): the UK `lists.yaml`, one field edited as a user
  edits it, and the file may differ only on that field's lines.
- **The Configurator leg is one declaration** (§7a).

Two answers an edit can need are the user's to give, and one piece of UI gives both for every
section on a draft (`Screens/Configurator/Drafts/DraftNotice`): a `Reformat` plan (today only a
YAML rule block that can no longer be one) shows the exact lines before and after and is applied
only on Apply Edit; a `Refused` plan (a comment between the elements of a bracketed list being
rearranged, a key that already exists) shows the reason and the line and changes nothing. A file
the document model cannot follow at all (anchors, a keep indicator, a duplicate key) opens
read-only with the reason and line.

---

## 5 · YAML write-back is refused for every file but lists, and both real sector files are YAML

Every writer but `ListsConfigWriter` resolves the on-disk extension through `ConfigPathResolver.Resolve` and **fails** if it is `.yaml`/`.yml`:

```csharp
if (resolved.IsYaml)
    return ConfigWriteResult.Fail("This system's mapstyle config is YAML; YAML write-back is not supported yet.");
```

This is not hypothetical. Checked against the two real sector files:

```
$ ls @sectorsrc/UK-Sector-File/package/systems/default
labels.json  mapstyle.yaml  policy.json  targets.json
$ ls @sectorsrc/UK-Sector-File/package/systems
default  expressions.json  gatwick-smr  lgw  lhr  'lists copy.yaml'  lists.yaml  node  sco  shapes.json  smr  stc
```

`@sectorsrc/LFXX-Sector-File` is identical in shape: `mapstyle.yaml` per system, `lists.yaml` at
the root. So **today, a new mapstyle field cannot be edited in the Configurator for either
shipping sector file** — the save refuses with the message above. `lists.yaml` saves (§4a), and
targets, labels, expressions and shapes are JSON and do save.

Plan for this up front. A mapstyle field is author-edits-YAML-by-hand until that section moves
onto the document model as lists has. The Configurator says so: a section whose file is YAML and
is not yet on a draft shows a read-only banner before any edit, stays browsable, and a save
reports that the file is YAML and was not written.

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
   `mapstyle.yaml`, say so explicitly per §5 — the Configurator is not the path. `lists.yaml` is
   editable in the Configurator once the field is declared (§7a).
4. **Re-convert needed?** Only if §1 shows a CLI emitter for that file. Systems configs never
   need a re-convert; a manifest or `.stp` field usually does (`neoradar-cli convert`).
5. **Write-back safety.** State that the writer round-trips the field, and that the round-trip
   test exists and is named. This is the line that certifies no author data is erased. For a
   `lists` field the statement is that the file is edited as a document (§4a), so a save writes
   nothing the user did not change.

Cross-check: `@sectorsrc/UK-Sector-File` and `@sectorsrc/LFXX-Sector-File` are the two live
consumers. If a claim in your rollout note is not true of both of them, it is not true.

---

## 7 · The Configurator section leg

Sections live in `@client/src/NeoRadar/Screens/Configurator/Sections/`. Each is **one
registration** in `ConfiguratorSections.AddConfiguratorSections`
(`AddConfiguratorSection<TViewModel, TView>(id, label, icon, group, order, scopeHint)`), and its view
model is resolved from DI when the shell is built, so a new constructor dependency only has to be
registered. The shell names no section; what it asks of one is the interfaces its view model
implements.

Two shell contracts:

| Contract | File | Obligation |
|---|---|---|
| `IConfiguratorSaveable` | `Screens/Configurator/IConfiguratorSaveable.cs` | `IsDirty`, `DirtyChanged`, `TrySave()`, `SaveStatus` / `SaveFailed` (the footer shows them), `File`, `DiscardEdits()`, `ReloadIfStale()`. The shell saves every dirty section, not only the one on show. |
| `IConfiguratorScopedSection` | `Screens/Configurator/IConfiguratorScopedSection.cs` | `SetSystem(AtmSystem?)`. System-scoped sections re-read on every switch and resolve the store's current instance by id; never cache the system. |

Three rules every section but Lists follows (`src/NeoRadar/CLAUDE.md` § Configurator); Lists
keeps the last two and replaces the first with a draft of the document (§7a):

- **It edits a copy.** The model is cloned on load (`ConfiguratorClone`); the store is never touched,
  so nothing is live before a save and a cancel has nothing to undo.
- **One save path.** `TrySave` calls the Core writer; the reload the writer announces is the only
  thing that changes the store. Never call a store setter from a section.
- **Conflicts are refused, not overwritten.** `ConfiguratorFileState` hashes the file at load;
  `File.SaveRefusal()` runs first in `TrySave` (YAML, or the file moved on disk), and
  `File.MarkSaved(...)` after a successful write.

`TargetsSectionViewModel` is the reference implementation. The pattern for one new field:

1. An `[ObservableProperty]` for the editable value.
2. Its `nameof(...)` added to the section's edit-field set so a change marks dirty (`s_editFields`).
3. Seed it in the inspector's seed method from the working copy, and keep the authored value in the
   seed snapshot.
4. Write it in `ApplyField` under its own `case`: only the field that changed is written, and a
   field set back to what it was seeded with writes the authored value back
   (`TagItemFields.KeptString` and friends). Never re-apply the whole inspector: that stamps a
   default into every field the file left absent.
5. A picker over a vocabulary takes it from the code that parses the value, and offers the current
   value before it is written (`PickerOptions`), or the ComboBox nulls a value it does not list.
6. The XAML row. Do not put a `LineHeight`, `Padding` or `Height` on the control by feel; see
   the `ui-text-metrics` skill.

Then extend `ConfiguratorOneEditTests` (`tests/NeoRadar.Tests/Screens/Configurator/`): load the
real-file fixture, edit the new field, save, and assert the file differs from an unedited save at
that field alone.

`TrySave` must surface failure rather than swallowing it: set `SaveFailed` + `SaveStatus` from
`ConfigWriteResult.Errors` and return `false`. Silent success on a refused write is the worst
outcome, because the author believes the edit landed.

### 7a · A lists field is one declaration

The Lists section has no hand-wired field. `Sections/ListFields.cs` declares every property of
the lists schema once: `OfList` and `OfColumn` are `FieldDeclaration`s (the dotted path under the
list or the column, a label, a `FieldKind`, a heading, and what the kind needs: a range, a
vocabulary read from Core, what an absent key reads as), and `NotEdited` gives each property with
no editor its reason. The view model builds one editor per declaration
(`Fields/FieldEditors.Create`, one editor class per kind) and the view is generated from them.
For a new lists field:

1. Copy the changed `@schemas/systems/lists.schema.json` over
   `tests/NeoRadar.Tests/Screens/Configurator/Fixtures/lists.schema.json`.
   `ListFieldsSchemaTests` now fails, naming the property: a schema property is a declared field
   or has a stated reason, or the build is red.
2. Add one `FieldDeclaration` line (or one `NotEdited` reason). A vocabulary comes from the code
   that parses the value, never a list typed here.
3. Move the pinned counts in `ListFieldsSchemaTests` and `ListsOneEditOnTheRealFileTests`. The
   second then sets the new field on the real UK file with no further code, and clears it if
   the file writes it.

A value the client reads in a shape no kind holds yet is a new `FieldKind` plus its editor class
and its template in `Fields/FieldEditorView.axaml`, never a special case in the section.

---

## 8 · Checklist

- [ ] Owning file identified in §1, and the CLI leg confirmed to exist or not exist.
- [ ] Schema property added as optional, not in `required`, no narrowing or rename.
- [ ] Parser accepts it; absent means the documented pre-change default.
- [ ] For mapstyle: `AtmSystem` property + `MapStyleParser` + `MapStyleSerializer` all four edited.
- [ ] Writer round-trips it. No `[Required]` retro-fitted to any list-element type.
- [ ] Round-trip test added to `ConfigWriterTests` and named after what it protects; suite green.
- [ ] New serialisable **type** registered in both `CoreJsonContexts` contexts (new property only, no edit).
- [ ] Configurator section reads it, marks dirty, writes only it back, and reports write failure;
      `ConfiguratorOneEditTests` covers it.
- [ ] For lists: the pinned schema copy refreshed, the field declared in `ListFields` (or excused in
      `NotEdited`), `ListFieldsSchemaTests` and `ListsOneEditOnTheRealFileTests` green; no writer leg.
- [ ] YAML refusal accounted for if the field lives in mapstyle.
- [ ] Rollout path written, all five lines, checked against both live sector files.
