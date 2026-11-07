---
name: package-config-field
description: Use when adding or changing a package format field end to end (add a config field, new mapstyle, targets, policy, tag item or profile property, extend the manifest, new option for a list column), or asking why is my package field ignored, why did the Configurator delete my field, why is the field red in my editor; or a new package file the client watches, a new Configurator section, or a sector-file rollout.
---

> **Shared skill.** Copied verbatim into `@client`, `@cli`, `@schemas`. Editing one copy alone is a break, not a cleanup.
# Adding a package config field, end to end

A package config field is not one edit. It exists in up to five places and a field present in
only some of them fails **silently**: no error, no log, the value simply disappears. This skill
is the ordering and the verification.

Cross-repo ordering, repo id resolution and the lockstep pairs are the
`cross-repo-contract-change` skill's job. Read that first if you do not have all the checkouts.
This skill is the field-level procedure inside that order.

Comment style: root `CLAUDE.md` § Writing rules and `@client .claude/rules/csharp-style.md`.

---

## 1 · Locate the field: which file owns it?

The legs you must edit depend entirely on **which package file** the field lives in. Get this
wrong and you will hunt for a CLI emitter that does not exist.

| File | Schema | CLI emitter | Client parser | Configurator writer |
|---|---|---|---|---|
| `systems/<id>/targets.{json,yaml}` | `@schemas/systems/targets.schema.json` | **none** | `@client/src/NeoRadar.Core/Package/TargetConfig.cs` | `SystemConfigWriter.WriteTargets`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/<id>/labels.{json,yaml}` | `@schemas/systems/labels.schema.json` | **none** | `Package/LabelsConfig.cs` | `SystemConfigWriter.WriteLabels`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/<id>/mapstyle.{json,yaml}` | `@schemas/systems/mapstyle.schema.json` | **none** | `Package/MapStyleParser.cs` (hand-written) | `SystemConfigWriter.WriteMapStyle`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/<id>/policy.{json,yaml}` | `@schemas/systems/policy.schema.json` | **none** | `Package/SystemPolicy.cs` plus the owning module's section type | `PolicyConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/shapes.{json,yaml}` | `@schemas/systems/shapes.schema.json` | **none** | `Package/ShapesConfig.cs` | `ShapesConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/expressions.{json,yaml}` | `@schemas/systems/expressions.schema.json` | **none** | `Package/ExpressionsConfig.cs` | `ExpressionsConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/lists.{json,yaml}` | `@schemas/systems/lists.schema.json` | **none** | `Package/ListsConfig.cs` | `ListsConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `manifest.json` | `@schemas/package/manifest.schema.json` | `initPackage` (`@cli/src/commands/init-package.ts`), `indexer` (`@cli/src/commands/indexer.ts`) | `Package/PackageManifest.cs` | `ManifestWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a). The keys the client writes itself (`lastActiveProfile` and `plugins` while a package is in use; `lastOpened`, `ignorePaths`, `installedFiles` and `remoteSource` from the launcher; `version` from an update) are set one at a time in the file's own text by `Package/ManifestKeyPatch`; all but `version` are never edited in the section, and `version`, which an update sets, is also a field of it |
| `profiles/*.stp` | `@schemas/profile.schema.json` | `AsrFolderConverter.processFile` (`@cli/src/commands/converter/asr.ts`) | `Package/Profiles/Profile.cs` | `ProfileStorageService.Write`, which writes the edited `PackageDocument` as it stands (§4a) as the local copy, the package file or both. The radar's own save of a profile (`ProfileStore.SaveUserProfile`) sets the values that differ in the file's own text (`ProfileFileDifference`, §4): a profile key the model does not hold is kept |
| `datasets/atc-data.json` | none | `AtcDataManager.writeAtcData` (`@cli/src/commands/converter/atc-data-parser.ts`) | `Package/AtcData.cs` | none |
| `datasets/nse.json` | none | `@cli/src/helper/nse.ts` | `Package/EseDataset.cs` | none |
| `datasets/<source>.geojson`, a manifest `mapLayers` layer (`maps/` for TopSky folders) | `@schemas/datasets/map-layer.schema.json` | `writeLayerFile` (`@cli/src/helper/layer-file.ts`), from `generateGeoJsonFilesForType` and the TopSky maps stage | `Package/Layers/LayerHeaderReader.cs` (the header: `name`, `origin`, `tags`, `conditions`, `items` with their `order`, `showWhen`, which `MapItems/` judges, `includes` and `listed`, and each drawing's `showWhen`, found past the table without parsing a feature), `GeoJson/GeoJsonLoader.cs` (the header's `symbols` and item orders, and the drawings: styles, text and its `textStyle`, `symbol`, zoom limits, `tags`, and its `showWhen` spelled as the header's to key its item index) | none: a generated file is rewritten by the next build, so no section edits one and nothing in the client writes one. Map Edit shows each `showWhen` read only beside its state and lists no `listed: false` item, the reference index counts the names an item's, a drawing's and a named condition's hold (a `"$name"` the file's own `conditions` define is no expression's use), `.dev map-info` prints the drawing verdicts and an unlisted item, and a change on disk is read again (`LayerFileChanged`) |
| `datasets/zones.geojson` | `@schemas/datasets/zones.schema.json` | **none** (hand-authored) | `Package/ZonesDataset.cs`, built into zones by `Sectors/ZoneIndex.cs` | `ZonesDatasetWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): a zone's `properties.tags`, `id`, `floor` and `ceiling` only, never a coordinate, and it creates no file |
| `datasets/radars.json` | `@schemas/datasets/radars.schema.json` | `writeRadarsDataset` (`@cli/src/helper/radars.ts`) | `Package/RadarsDataset.cs` | none |
| `datasets/msaw.geojson` | `@schemas/datasets/msaw.schema.json` | `buildMsawDataset` (`@cli/src/commands/converter/topsky/topsky-msaw.ts`) | `Package/MsawDataset.cs` | none |
| `datasets/areas.geojson` | `@schemas/datasets/areas.schema.json` | `buildAreasDataset` (`.../topsky/topsky-areas.ts`) | `Package/AreasDataset.cs` (name, category, `label` (its `x`, `y` and `text`), `preActiveS`, `uuid`, limits, `activation`: `when`, `lowerFt`, `upperFt`, `userText`, `aup`; `display`: the `active` and `preActive` looks and the reduced label's items; the geometry; and the file's own `display`: label font, colours, `aupUserText`), judged by `MapItems/AreaActivation/` and drawn by the desktop's `AreaDisplayModule`; its `origin` and `items` are a map layer header, read by `Package/Layers/LayerHeaderReader` | none: no section edits the file and nothing in the client writes it, so every byte stays; Map Edit shows its items as every layer's |
| `datasets/cas.geojson` | `@schemas/datasets/cas.schema.json` | `writeControlledAirspace` (`@cli/src/commands/converter/cas.ts`), from the sector file and the vAcc's `data/cas.json` | `SafetyNets/Aiw/CasDataset.cs`, loaded by `Aiw/ControlledAirspaceStore` | none |
| `datasets/stca-runways.json` | `@schemas/datasets/stca-runways.schema.json` | `buildStcaRunwaysDataset` (`.../topsky/topsky-stca.ts`) | not read by the client | none |
| `server-dataset.json` | none | `@cli/src/helper/server-dataset.ts` (`areaActivation.aupUrl` from `TopSkySettings.txt` `HTTP_AUP_URL`) | not read by the client; `@server` imports it | none |

`policy.json`, `targets.json`, `labels.json`, a mapstyle, the expressions file and the shapes file are edited as documents, as lists is (§4a): the section holds the file's own text, so the §4 erase-on-save hazard does not apply to them and the test in §8 is the schema test of §7a instead. A system with no policy file gets one at the first save that has something in it. Its sections are owned by the modules that consume them (`Correlation/CorrelationPolicySection.cs` is the model), not by `Package/`, so a new section is a property on `SystemPolicy` plus a section type and a `Resolve` beside the module that reads it, called from both `SystemPolicies.Resolve` and `SystemPolicies.ResolveEachSection` (the load's, where a section that cannot be read is taken down alone: a net off, anything else on its absent default); a new safety net also adds its line to `ResolveSafetyNetsEachNet` and `EveryNetOff`.

**The `systems/*` configs have no CLI leg.** `downloadBasePackage` (`@cli/src/commands/init-package.ts`)
downloads the whole starter tree from the `neoradar-project/base-package` release and unzips it; the
CLI never generates or rewrites a systems config. The only `$schema` keys it writes are on the five
datasets it emits (`radars`, `msaw`, `areas`, `stca-runways`, `cas`) and the two reference data files its import
commands write (`holds`, `altimetry`, schemas under `@schemas/data/`; `grep -rn '\$schema' @cli/src`), so a
dataset schema that moves needs its constant there moved too. A new systems-config field therefore lands in
`@schemas` + `@client` + optionally the base-package template, and the "emitter" step is a no-op.

`TagItem` is the shared shape used by both tag grids and list columns
(`TagItem` in `@client/src/NeoRadar.Core/Package/LabelsConfig.cs`), so a `TagItem` field appears in the
labels schema **and** the lists schema and reaches two Configurator sections through ONE declaration
(`Sections/TagItemFields.Fields`, §7a).

---

## 2 · The order, and why it is not negotiable

`@schemas` has no versioning and no pinned ref: sector files reference the raw URL on `main`,
so a merge is instantly live for every author. Verified in the real sector files:
the `$schema` key of `@sectorsrc/UK-Sector-File/package/systems/*/targets.json` uses
`.../schemas/refs/heads/main/systems/targets.schema.json`, and the YAML siblings use a
`# yaml-language-server: $schema=.../schemas/main/systems/mapstyle.schema.json` first line.

Every root schema except `lists` sets **`additionalProperties: false`**:

```
$ python -c "import json,glob; [print(f, json.load(open(f,encoding='utf-8')).get('additionalProperties','ABSENT')) for f in sorted(glob.glob('systems/*.json')+glob.glob('datasets/*.json'))]"
datasets\areas.schema.json        False
datasets\cas.schema.json          False
datasets\map-layer.schema.json    False
datasets\msaw.schema.json         False
datasets\path-rules.schema.json   False
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

1. **`@schemas`**: add the property as **optional**. Widening is safe. Do not add it to
   `required`; do not narrow or rename an existing property.
2. **`@client` parser**: accept it, with the absent case producing the documented default.
3. **`@client` writer**: round-trip it. See §4; skipping this deletes author data.
4. **`@client` Configurator section**: expose it (optional, but a field with no UI is a field
   nobody uses).
5. **`@cli`**: only if §1 says there is an emitter for that file.
6. **Rollout note**: §6. Mandatory, not optional.

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
`YamlToJson`. You get YAML support for free, and YAML **write** support with it for every file the
Configurator edits as a document (§4a): `lists`, `policy`, `targets`, `labels`, `mapstyle`, `expressions` and `shapes`. One
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

Read it through `DynamicValueResolver` (the `@client` skill `tag-and-list-authoring` lists the readers; the
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
only to read a draft as the loader will, and every write still goes through the Core writer interfaces.

Validation is `DataAnnotations` via `PackageValidator` (`Package/PackageValidator.cs`). Note the
asymmetry, it matters for rollout:

- `PackageValidator.Validate<T>` **warns and continues**: an invalid object still loads.
- `PackageValidator.ValidateList<T>` **drops the invalid element**, so adding `[Required]` to a
  `DynamicListConfig` or `TagItem` field silently removes whole entries from every package that
  predates the field. Never retro-fit `[Required]`.

### Hand-written (mapstyle only)

`SystemMapStyle` uses tuples and is parsed by `MapStyleParser.Parse`. A mapstyle field is **three**
edits for the client to read it: the `AtmSystem.cs` property, the parser `TryGetProperty` line and
the schema. Nothing serialises the model, so there is no fourth; the Configurator leg is one
declaration in `MapStyleFields` (§7a).

---

## 4 · The writer leg: a property the radar's save skips is never saved

No package file is written whole from a typed model any more. The one typed thing left is the
radar's own save of a profile (`ProfileStore.SaveUserProfile`: the viewport, the filters, the map
items), and it is a patch: `ProfileCopy` copies the profile's values, `ProfileFileDifference`
compares each with what the loader reads from the file, and only what differs is set in the
file's own text. So a profile property the radar changes while the client runs needs three
things: the `Profile` property, its line in `ProfileCopy`, and its comparison in
`ProfileFileDifference`; `ProfileSaveTests.EveryPropertyOfTheProfileModel_IsCopiedForASave_AndIsComparedWithTheFileOrNamedAsLeftAlone`
fails one that is neither compared nor named as left alone. A key the model does not hold is
kept by that save, not deleted. Nothing the Configurator edits is written from a model either:
**`lists`, `policy`, `targets`, `labels`, `mapstyle`, `expressions`, `shapes`, the zones dataset,
the manifest and a profile** have no writer leg at all: §4a.

What follows in this section is why the rule was parser and writer in one change, and it is
still how the system folder writers validate.

**No config type in Core has `[JsonExtensionData]`**: verified,
`grep -rn JsonExtensionData src/NeoRadar.Core --include=*.cs` returns nothing. Combined with a
typed writer writing only the fields it knows about, the consequence is:

> Before the radar's save became a patch, any property of a profile present on disk but absent
> from the client model was **erased** the first time the radar saved that profile.

That was a data-loss bug against a real author's package, not a cosmetic gap. It is why the rule
is parser **and** writer in the same change, and why the client leg is three files, not one:
parser (§3), writer (this section), Configurator section view model (§7).

All writes route through `Package/Writers/`:
`ISystemConfigWriter`, `IExpressionsConfigWriter`, `IListsConfigWriter`, `IShapesConfigWriter`,
`IPolicyConfigWriter`, `IZonesDatasetWriter`, `IManifestWriter`, `ISystemFolderWriter`, `IProfileStorageService`, all singletons, registered in
`PackageModule.AddPackageServices`. Every one of them writes through
`AtomicConfigWriter.Write` (tmp file + `File.Move` overwrite). Never `File.WriteAllText` a package file from a
section.

**A save reaches the running views through one path, and it is the on-disk path.** Each writer
tells `IOwnPackageWrites` (implemented by `Package/ReloadPackageFilesOnChange`) what it wrote, through
the member for its file: `SystemFile(path, systemId, geometryAffected)`, `PolicyFile(path, systemId)`,
`ListsFile`, `ExpressionsFile`, `ShapesFile`, `ZonesFile`, `ManifestFile` (the manifest: the package
is read again from it and `ManifestFileChanged` announced), `SystemFolder(systemId)` (a system
folder created, filled, removed or renamed: the store gains or drops the system and
`SystemListChanged` is announced), `ProfileFile(path)` (a profile file written or patched on disk:
it is read again and the views showing it re-apply it), `ProfileFileRemoved(path)` (a profile file
deleted with nothing left to read: the views are told and the stores drop the profile),
`ProfileInMemory(profile)` for a stored profile edited in place by Map Edit, and `Unwatched(path)` for a file whose content the stores already hold. The watcher's echo of that write is ignored, the file is reloaded into the store once,
and the typed `*FileChanged` bus event tells every open radar view, main window and insets alike,
to re-apply what it shows. An edit made in a text editor arrives at the same reload through
`PackageFileWatcher`. A section never publishes a reload event and never pokes a view; a new
writer that skips the `IOwnPackageWrites` call saves correctly and shows nothing until restart. A
new package FILE needs a watcher entry, a `Reload*` on `IPackageLoaderService` and its event as
well (`datasets/msaw.geojson` is the model).

A new package file the client watches, in order (`ReloadPackageFilesOnChangeTests`):
1. a watcher entry in `PackageFileWatcher`;
2. a `Reload*` on `IPackageLoaderService`;
3. a typed `*FileChanged` event;
4. one line in `ReloadPackageFilesOnChange`, following `msaw.geojson`;
5. if a Configurator writer saves it, an `IOwnPackageWrites` notice naming it so the echo is ignored and
   the same reload runs once.

A new `Profile` property: copy it in `ProfileCopy` and compare it in `ProfileFileDifference` (or name it
as left alone), in the same piece of work as the Configurator field.

If the field has a structural invariant, add it to that writer's validation list so the write
fails before touching disk; `SystemConfigWriter.ValidateTargets` and `ValidateLabels` are the model
(each runs on the typed read of the document a save hands over), and the failure path returns
`ConfigWriteResult.Fail` and writes nothing.

### Round-trip test (required)

Extend `@client/tests/NeoRadar.Core.Tests/Package/ConfigWriterTests.cs` (system folders; a
file edited as a document has no round trip to test, §4a) or, for a profile property the radar
must keep, `ProfileStoreTests`. Most of
its facts are in this exact shape: parse a JSON literal, write, re-parse from disk, assert the field
survived. Name the test after what it protects.

```
dotnet test tests/NeoRadar.Core.Tests/NeoRadar.Core.Tests.csproj --filter ConfigWriterTests
```

---

## 4a · Lists, policy, targets, labels, mapstyle, expressions and shapes are edited as documents: nothing is serialised, so nothing is deleted

Read reference/document-writers.md when you change or add a writer, add a manifest key the client writes, or need
to know what a file's writer reads the document as and refuses: it is each file's writer in turn.

Consequences for a new lists, policy, targets, labels, mapstyle, expressions, shapes, manifest or profile field:

- **A field the client model does not know survives every save**, with its comments, key order,
  quoting, rule blocks and line endings. There is no erase-on-save hazard.
- **There is no writer leg and no `ConfigWriterTests` round-trip.** The parser leg (§3) is still
  what makes the client READ the field. What a save writes is pinned by
  `ListsConfigWriterTests` (Core) and, per field, by
  `ListsOneEditOnTheRealFileTests` (desktop): the UK `lists.yaml`, one field edited as a user
  edits it, and the file may differ only on that field's lines. Policy has the same pair:
  `PolicyConfigWriterTests` and `PolicyOneEditOnTheRealFileTests` over the UK `lhr/policy.json`,
  targets `TargetsConfigWriterTests` and `TargetsOneEditOnTheRealFileTests` over the UK
  `default` and `lhr` `targets.json`, and labels `LabelsConfigWriterTests` and
  `LabelsOneEditOnTheRealFileTests` over the UK `default` and `lhr` `labels.json`, and mapstyle
  `MapStyleConfigWriterTests` and `MapStyleOneEditOnTheRealFileTests` over the eight UK
  `mapstyle.yaml` files and the four LFXX ones, and expressions `ExpressionsConfigWriterTests` and
  `ExpressionsOneEditOnTheRealFileTests` over the UK `expressions.json` and the same 91 expressions
  and 79 rules written as YAML with comments, and shapes `ShapesDocumentWriterTests` and
  `ShapesOneEditOnTheRealFileTests` over the UK `shapes.json` and the same 8 shapes written as YAML
  with comments, and the manifest `ManifestWriterTests` and `ManifestOneEditOnTheRealFileTests` over
  the manifests of the built UK and LFXX packages (the second holds `devDisableAntialiasing`,
  which the model does not know), and a profile `ProfileStorageServiceTests` and
  `ProfilesOneEditOnTheRealFileTests` over the five pinned egxx profiles (one holds `groupLabel`,
  `filePath`, `lastModified` and `_saveMetadata`, which the model does not know).
- **The Configurator leg is one declaration** (§7a).

Two answers an edit can need are the user's to give, and one piece of UI gives both for every
section on a draft (`Screens/Configurator/Drafts/DraftNotice`): a `Reformat` plan (today only a
YAML rule block that can no longer be one) shows the exact lines before and after and is applied
only on Apply Edit; a `Refused` plan (a comment between the elements of a bracketed list being
rearranged, a key that already exists) shows the reason and the line and changes nothing. A file
the document model cannot follow at all (anchors, a keep indicator, a duplicate key) opens
read-only with the reason and line.

---

## 5 · Every systems file saves in YAML too, and both real sector files use it

No writer refuses YAML any more. `ListsConfigWriter`, `PolicyConfigWriter`, `ExpressionsConfigWriter`,
`ShapesConfigWriter` and `SystemConfigWriter.WriteTargets`, `.WriteLabels` and `.WriteMapStyle` each take
a `PackageDocument` and write its own bytes over the `.json`, `.yaml` or `.yml` the package holds. The one
refusal left is a document of the other format than the file on disk:

```csharp
if (resolved.IsYaml != (document.Format == DocumentFormat.Yaml))
    return ConfigWriteResult.Fail("... is not the ... file these ... were loaded from, so it was not written.");
```

That matters because the two real sector files are YAML where it counts:

```
$ ls @sectorsrc/UK-Sector-File/package/systems/default
'labels copy 2.json'  'labels copy.json'  labels.json  mapstyle.yaml  policy.json  targets.json
$ ls @sectorsrc/UK-Sector-File/package/systems
default  expressions.json  gatwick-smr  lgw  lhr  lists.yaml  node  sco  shapes.json  smr  stc
```

`@sectorsrc/LFXX-Sector-File` is identical in shape: `mapstyle.yaml` per system, `lists.yaml` at
the root. A mapstyle saves in either format (§4a), so a new mapstyle field is edited in the
Configurator for both shipping sector files. `lists.yaml` saves too, as does a targets, a labels,
an expressions or a shapes file in either format. The four LFXX `labels.json` files are in an older layout the client no longer reads (a
section holding bare row grids in place of `labels`): the Tags section opens them read-only and
says so; they are converted by hand.

Three files are JSON only: the manifest, because the loader reads `manifest.json` and nothing else,
a profile, which is a `.stp`, and the zones dataset, whose writer refuses a document that is not JSON. The read-only banner
now means a file the document model cannot follow, or one that is not the shape its section expects
(a shapes file whose `shapes` is no map, a labels file in the older layout); it names the reason,
and a save reports the same.

---

## 6 · Rollout path for sector files that predate the field

Required in the change description. Fill in all five lines; "n/a" is a valid answer but silence
is not.

1. **Absent-field behaviour.** What does a package without the field do? Name the default and
   where it comes from (a property initialiser, or the parser's untouched default). It must be
   the pre-change behaviour, exactly.
2. **Editor impact.** The schema edit is live on `main` the moment it merges. Confirm the
   property is optional and not in `required`, so no existing file starts erroring.
3. **Author action.** Nothing (widening), or a documented manual edit. A lists, policy,
   targets, labels, mapstyle, expressions, shapes or manifest field is editable in the
   Configurator once the field is declared (§7a). If the manifest key is one the client writes
   itself at run time, say so: it has no editor by decision.
4. **Re-convert needed?** Only if §1 shows a CLI emitter for that file. Systems configs never
   need a re-convert; a manifest or `.stp` field usually does (`neoradar-cli convert`).
5. **Write-back safety.** State that the writer round-trips the field, and that the round-trip
   test exists and is named. This is the line that certifies no author data is erased. For a
   `lists`, `policy`, `targets`, `labels`, `mapstyle`, `expressions`, `shapes` or manifest field the statement is that the file is
   edited as a document (§4a), so a save writes nothing the user did not change.

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

Three rules every section follows (`@client .claude/rules/configurator-shell.md` § Saving):

- **Nothing is live before a save.** Every section that edits a file holds a draft of the
  document (§7a) and never touches the store, Profiles among them.
- **One save path.** `TrySave` calls the Core writer; the reload the writer announces is the only
  thing that changes the store. Never call a store setter from a section.
- **Conflicts are refused, not overwritten.** `ConfiguratorFileState` hashes the file at load;
  `File.SaveRefusal()` runs first in `TrySave` (the file moved on disk), and
  `File.MarkSaved(...)` after a successful write. Two files the client itself writes under an
  open draft are the exception, each in its own way: a manifest save takes the client's keys from
  the file as it is then, and a profile save sets the author's edited fields again on the file
  as it is then.

No section that edits a file is hand-wired any more: a new field is one declaration (§7a).
Systems works on folders and Map Edit on the profile the radar holds; neither has fields.

`TrySave` must surface failure rather than swallowing it: set `SaveFailed` + `SaveStatus` from
`ConfigWriteResult.Errors` and return `false`. Silent success on a refused write is the worst
outcome, because the author believes the edit landed.

### What a new piece of the Configurator owes the shell

Each line points at the `@client .claude/rules/configurator-*.md` file that states the rule; the rule is
stated there once.

- A new section: one `AddConfiguratorSection<TViewModel, TView>(id, label, icon, group, order,
  scopeHint)` line in `ConfiguratorSections.AddConfiguratorSections`, the interfaces it implements
  being what the shell asks of it (`@client configurator-shell.md` § Sections).
- A new text in a view takes a `cfg_text_*` class; a moved view comes off the
  `NoConfiguratorView_SetsAFontSizeOnATextItself_ButTheViewsStillToMove` table (`@client configurator-shell.md` § Look).
- A new long column of generated rows wraps its row in `DeferredRow`; a test walking every editor
  calls `DeferredRows.BuildAllIn(view)` first (`@client configurator-shell.md` § Sections).
- A new operation that moves or rewrites package files outside its own section asks `UnsavedEdits`
  (`@client configurator-shell.md` § Saving).
- A new reference field needs only `FieldDeclaration.Names`; a section that gains a field the index
  judges passes the index (`@client configurator-references.md`).
- A new field kind gets clear-to-absent for nothing; one that edits several keys names them in
  `SiblingKeys` (`@client configurator-fields.md`).
- A new selector on a variant is a new probe in `Preview/VariantProbes` and a sentence in
  `Preview/NotDrawnReasons` (`@client configurator-previews.md`).
- A new engine use in the Configurator adds its row to
  `ExpressionsTruthLineTests.NoConfiguratorFile_ButThePreviewsOwn_HoldsATagEngineOrAnEvaluator_OrAsksOneAboutAnAircraft`
  (`@client configurator-previews.md`).
- The golden switches for the Configurator's frozen tables: `NEORADAR_UPDATE_REFERENCE_INDEX_GOLDEN=1`,
  `NEORADAR_UPDATE_PREVIEW_GOLDEN=1`, `NEORADAR_UPDATE_TARGET_PREVIEW_GOLDEN=1`,
  `NEORADAR_UPDATE_LISTS_PREVIEW_GOLDEN=1` (each also named beside its test in the rules files).

### 7a · A field is one declaration

Read reference/configurator-fields.md when you declare the field in its Configurator section: the three steps
for a lists field, then what is particular to policy, targets, labels, mapstyle, expressions, shapes, zones, the
manifest and a profile.

---

## 8 · Checklist

- [ ] Owning file identified in §1, and the CLI leg confirmed to exist or not exist.
- [ ] Schema property added as optional, not in `required`, no narrowing or rename.
- [ ] Parser accepts it; absent means the documented pre-change default.
- [ ] For mapstyle: `AtmSystem` property + `MapStyleParser` + the schema edited.
- [ ] Writer round-trips it. No `[Required]` retro-fitted to any list-element type.
- [ ] Round-trip test added to `ConfigWriterTests` (a system folder) or `ProfileStoreTests` (a profile property the radar must keep) and named after what it protects; suite green.
- [ ] New serialisable **type** registered in both `CoreJsonContexts` contexts (new property only, no edit).
- [ ] For lists: the pinned schema copy refreshed, the field declared in `ListFields` (or excused in
      `NotEdited`), `ListFieldsSchemaTests` and `ListsOneEditOnTheRealFileTests` green; no writer leg.
- [ ] For policy: the same with `PolicyFields`, `PolicyFieldsSchemaTests` and
      `PolicyOneEditOnTheRealFileTests`; a unit in every number's label; a section in force by being
      written declared `Block`.
- [ ] For targets: the same with `TargetFields`, `TargetFieldsSchemaTests` and
      `TargetsOneEditOnTheRealFileTests`; a number's default held to the reader; a new selector
      taught to `UnreachableVariants`; no writer leg.
- [ ] For labels: the same with `LabelFields` (or `TagItemFields` for an item field, which reaches
      Lists too), `LabelFieldsSchemaTests` / `TagItemFieldsSchemaTests` and
      `LabelsOneEditOnTheRealFileTests`; a new selector taught to `UnreachableVariants`; no writer leg.
- [ ] For mapstyle: the pinned schema copy refreshed, the field declared in `MapStyleFields` (or
      excused in `NotEdited` with the reader that does not read it), `MapStyleFieldsSchemaTests` and
      `MapStyleOneEditOnTheRealFileTests` green (move the 172, 107 and 65); no writer leg.
- [ ] For expressions: the pinned schema copy refreshed, the field declared in `ExpressionFields` (or
      excused in `NotEdited`), `ExpressionFieldsSchemaTests` and `ExpressionsOneEditOnTheRealFileTests`
      green; a new operator or condition form taught to `ExpressionParser` and `ConditionNode` with its
      characterisation row; no writer leg.
- [ ] For shapes: the pinned schema copy refreshed, the field declared in `ShapeFields` (or excused in
      `NotEdited`), shown for the kinds that read it, its absent-key row added, `ShapeFieldsSchemaTests`,
      `ShapesOneEditOnTheRealFileTests` and the characterisation table green; no writer leg.
- [ ] For zones: the pinned schema copy refreshed, the property declared in `ZoneFields` (or excused
      in `NotEdited`), read by `ZoneProperties` and `ZoneIndex`, `ZoneFieldsSchemaTests` and
      `ZonesOneEditOnTheRealFileTests` green; a new policy key naming a zone tag added to
      `ZoneTagsThePoliciesRead`; no geometry edited.
- [ ] For the manifest: the pinned schema copy refreshed, the property declared in `ManifestFields` (or
      excused in `NotEdited`; a key the client writes at run time is excused as the client's and
      added to `WrittenByTheClient`), `ManifestFieldsSchemaTests` and
      `ManifestOneEditOnTheRealFileTests` green; a rule the loader enforces added to
      `ManifestWriter.Validate`; no writer leg.
- [ ] For a profile: the pinned schema copy refreshed, the property declared in `ProfileFields` (or
      excused in `NotEdited`; what the radar's own menus set is excused as the controller's), the
      model property added so the radar's save keeps it, `ProfileFieldsSchemaTests` and
      `ProfilesOneEditOnTheRealFileTests` green; a rule the loader enforces added to
      `ProfileStorageService.Check`.
- [ ] A new kind of package-check finding is an `AuthoringFindingKind` member and its check in
      `Package/Authoring/`, with a bug-named test in `PackageAuthoringCheckTests`
      (`CheckPackageAuthoringTests`, `PackageCheckWiringTests`).
- [ ] Rollout path written, all five lines, checked against both live sector files.
