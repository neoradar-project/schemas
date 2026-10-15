---
name: package-config-field
description: Add or change a field in the NeoRadar package format end to end. Use when the user says add a config field, new mapstyle property, new targets property, new tag item property, extend the manifest, new option for a list column, why is my package field ignored, why did the Configurator delete my field, why is the field red in my editor, or asks how a schema change reaches sector-file authors. Covers the schema-first ordering across @schemas @cli and @client, the parser plus writer round-trip rule that stops a field being silently dropped, the Configurator section wiring, the document model that saves YAML (lists, policy, targets, labels, mapstyle, expressions, shapes, the properties of the zones dataset, the manifest and a profile are edited as documents; no writer refuses YAML any more), the manifest keys the client writes itself and patches one at a time, and the mandatory rollout path for sector files that predate the field.
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
| `systems/<id>/targets.{json,yaml}` | `@schemas/systems/targets.schema.json` | **none** | `@client/src/NeoRadar.Core/Package/TargetConfig.cs` | `SystemConfigWriter.WriteTargets`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/<id>/labels.{json,yaml}` | `@schemas/systems/labels.schema.json` | **none** | `Package/LabelsConfig.cs` | `SystemConfigWriter.WriteLabels`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/<id>/mapstyle.{json,yaml}` | `@schemas/systems/mapstyle.schema.json` | **none** | `Package/MapStyleParser.cs` (hand-written) | `SystemConfigWriter.WriteMapStyle`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/<id>/policy.{json,yaml}` | `@schemas/systems/policy.schema.json` | **none** | `Package/SystemPolicy.cs` plus the owning module's section type | `PolicyConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/shapes.{json,yaml}` | `@schemas/systems/shapes.schema.json` | **none** | `Package/ShapesConfig.cs` | `ShapesConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/expressions.{json,yaml}` | `@schemas/systems/expressions.schema.json` | **none** | `Package/ExpressionsConfig.cs` | `ExpressionsConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `systems/lists.{json,yaml}` | `@schemas/systems/lists.schema.json` | **none** | `Package/ListsConfig.cs` | `ListsConfigWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): no model is serialised, so there is no writer leg |
| `manifest.json` | `@schemas/package/manifest.schema.json` | `initPackage` (`@cli/src/commands/init-package.ts`), `indexer` (`@cli/src/commands/indexer.ts`) | `Package/PackageManifest.cs` | `ManifestWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a). The keys the client writes itself (`lastActiveProfile`, `plugins` and `lastOpened` while a package is in use; `ignorePaths`, `version`, `installedFiles` and `remoteSource` from the launcher) are set one at a time in the file's own text by `Package/ManifestKeyPatch` and are never edited in the section |
| `profiles/*.stp` | `@schemas/profile.schema.json` | `AsrFolderConverter.processFile` (`@cli/src/commands/converter/asr.ts`) | `Package/Profiles/Profile.cs` | `ProfileStorageService.Write`, which writes the edited `PackageDocument` as it stands (§4a) as the local copy, the package file or both. The radar's own save of a profile (`ProfileStore.SaveUserProfile`) sets the values that differ in the file's own text (`ProfileFileDifference`, §4): a profile key the model does not hold is kept |
| `datasets/atc-data.json` | none | `AtcDataManager.writeAtcData` (`@cli/src/commands/converter/atc-data-parser.ts`) | `Package/AtcData.cs` | none |
| `datasets/nse.json` | none | `@cli/src/helper/nse.ts` | `Package/EseDataset.cs` | none |
| `datasets/<source>.geojson`, a manifest `mapLayers` layer (`maps/` for TopSky folders) | `@schemas/datasets/map-layer.schema.json` | `writeLayerFile` (`@cli/src/helper/layer-file.ts`), from `generateGeoJsonFilesForType` and the TopSky maps stage | `Package/Layers/LayerHeaderReader.cs` (the header: `name`, `origin`, `tags`, `conditions`, `items` with their `order`, `showWhen`, which `MapItems/` judges, `includes` and `listed`, and each drawing's `showWhen`, found past the table without parsing a feature), `GeoJson/GeoJsonLoader.cs` (the header's `symbols` and item orders, and the drawings: styles, text and its `textStyle`, `symbol`, zoom limits, `tags`, and its `showWhen` spelled as the header's to key its item index) | none: a generated file is rewritten by the next build, so no section edits one and nothing in the client writes one. Map Edit shows each `showWhen` read only beside its state and lists no `listed: false` item, the reference index counts the names an item's, a drawing's and a named condition's hold (a `"$name"` the file's own `conditions` define is no expression's use), `.dev map-info` prints the drawing verdicts and an unlisted item, and a change on disk is read again (`LayerFileChanged`) |
| `datasets/zones.geojson` | `@schemas/datasets/zones.schema.json` | **none** (hand-authored) | `Package/ZonesDataset.cs`, built into zones by `Sectors/ZoneIndex.cs` | `ZonesDatasetWriter.Write`, which writes the edited `PackageDocument` as it stands (§4a): a zone's `properties.tags`, `id`, `floor` and `ceiling` only, never a coordinate, and it creates no file |
| `datasets/radars.json` | `@schemas/datasets/radars.schema.json` | `writeRadarsDataset` (`@cli/src/helper/radars.ts`) | `Package/RadarsDataset.cs` | none |
| `datasets/msaw.geojson` | `@schemas/datasets/msaw.schema.json` | `buildMsawDataset` (`@cli/src/commands/converter/topsky/topsky-msaw.ts`) | `Package/MsawDataset.cs` | none |
| `datasets/areas.geojson` | `@schemas/datasets/areas.schema.json` | `buildAreasDataset` (`.../topsky/topsky-areas.ts`) | `Package/AreasDataset.cs` (name, category, `label` (its `x`, `y` and `text`), `preActiveS`, `uuid`, limits, `activation`: `when`, `lowerFt`, `upperFt`, `userText`, `aup`; `display`: the `active` and `preActive` looks and the reduced label's items; the geometry; and the file's own `display`: label font, colours, `aupUserText`), judged by `MapItems/AreaActivation/` and drawn by the desktop's `AreaDisplayModule`; its `origin` and `items` are a map layer header, read by `Package/Layers/LayerHeaderReader` | none: no section edits the file and nothing in the client writes it, so every byte stays; Map Edit shows its items as every layer's |
| `datasets/stca-runways.json` | `@schemas/datasets/stca-runways.schema.json` | `buildStcaRunwaysDataset` (`.../topsky/topsky-stca.ts`) | not read by the client | none |
| `server-dataset.json` | none | `@cli/src/helper/server-dataset.ts` (`areaActivation.aupUrl` from `TopSkySettings.txt` `HTTP_AUP_URL`) | not read by the client; `@server` imports it | none |

`policy.json`, `targets.json`, `labels.json`, a mapstyle, the expressions file and the shapes file are edited as documents, as lists is (§4a): the section holds the file's own text, so the §4 erase-on-save hazard does not apply to them and the test in §8 is the schema test of §7a instead. A system with no policy file gets one at the first save that has something in it. Its sections are owned by the modules that consume them (`Correlation/CorrelationPolicySection.cs` is the model), not by `Package/`, so a new section is a property on `SystemPolicy` plus a section type and a `Resolve` beside the module that reads it.

**The `systems/*` configs have no CLI leg.** `downloadBasePackage` (`@cli/src/commands/init-package.ts`)
downloads the whole starter tree from the `neoradar-project/base-package` release and unzips it; the
CLI never generates or rewrites a systems config. The only `$schema` keys it writes are on the four
datasets it emits (`radars`, `msaw`, `areas`, `stca-runways`; `grep -rn '\$schema' @cli/src`), so a
dataset schema that moves needs its constant there moved too. A new systems-config field therefore lands in
`@schemas` + `@client` + optionally the base-package template, and the "emitter" step is a no-op.

`TagItem` is the shared shape used by both tag grids and list columns
(`TagItem` in `@client/src/NeoRadar.Core/Package/LabelsConfig.cs`), so a `TagItem` field appears in the
labels schema **and** the lists schema and reaches two Configurator sections through ONE declaration
(`Sections/TagItemFields.Fields`, §7a).

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
only to read a draft as the loader will, and every write still goes through the Core writer interfaces.

Validation is `DataAnnotations` via `PackageValidator` (`Package/PackageValidator.cs`). Note the
asymmetry, it matters for rollout:

- `PackageValidator.Validate<T>` **warns and continues** — an invalid object still loads.
- `PackageValidator.ValidateList<T>` **drops the invalid element** — so adding `[Required]` to a
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

**No config type in Core has `[JsonExtensionData]`** — verified,
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

If the field has a structural invariant, add it to that writer's validation list so the write
fails before touching disk — `SystemConfigWriter.ValidateTargets` and `ValidateLabels` are the model
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

`systems/lists.{json,yaml,yml}` is the first file moved onto the document model
(`@client/src/NeoRadar.Core/Package/Documents/`). The Lists section holds the file's own text as a
`PackageDocument` inside a `DocumentDraft`; every change a user makes is one `DocumentEdit` at a
path (`SetValue`, `AddKey`, `Remove`, `InsertElement`, `MoveElement`, `RenameKey`), planned as one
patch of that text and checked by reading the patched text back through the client's own loader.
`ListsConfigWriter.Write(packagePath, document)` reads the document once as the loader will (a
file the client could not load is never written), writes `document.ToBytes()` through
`AtomicConfigWriter` and tells `IOwnPackageWrites.ListsFile`. The typed `DynamicListConfig` is only
ever READ from the document. `systems/<id>/policy.{json,yaml,yml}` is the second file on the model:
`PolicyConfigWriter.Write(packagePath, systemId, document)` resolves the document as the loader
will (`SystemPolicies.Resolve`, so a policy that would leave the system on defaults is never
written and the refusal carries the reader's own message) and tells
`IOwnPackageWrites.PolicyFile`, whose one reload publishes `PolicyFileChanged`.
`systems/<id>/targets.{json,yaml,yml}` is the third: `SystemConfigWriter.WriteTargets(packagePath,
systemId, document)` reads the document as the loader will, runs `ValidateTargets` on that read
(an unknown selector name in any list, an airborne variant with neither a sprite nor a shape),
and tells `IOwnPackageWrites.SystemFile` with `geometryAffected` false.
`systems/<id>/labels.{json,yaml,yml}` is the fourth: `SystemConfigWriter.WriteLabels(packagePath,
systemId, document)` reads the document as the loader will, its ground section too, runs
`ValidateLabels` on that read (an unknown selector name on a label variant or a style variant of
either section) and tells `IOwnPackageWrites.SystemFile` the same way. The typed `WriteLabels`,
its ground override and its YAML refusal are deleted.
`systems/<id>/mapstyle.{json,yaml,yml}` is the fifth: `SystemConfigWriter.WriteMapStyle(packagePath,
systemId, document)` reads the document as the loader reads the file (strict JSON, or YAML through
`YamlToJson`; a file naming no map of styles is refused) and tells `IOwnPackageWrites.SystemFile`
with `geometryAffected` true. The typed `WriteMapStyle`, `MapStyleSerializer` and the YAML refusal
are deleted.
`systems/expressions.{json,yaml,yml}` is the sixth: `ExpressionsConfigWriter.Write(packagePath,
document)` reads the document as the loader reads the file (a file that is no map, or whose
`expressions` or `rules` is no map, or a rule whose value is no text, is refused) and tells
`IOwnPackageWrites.ExpressionsFile`. A condition the parser rejects loads as one that is never true,
so the WRITER writes it; the Expressions SECTION is stricter and saves nothing while the client
cannot read the condition of any expression. The typed `Write`, its YAML refusal and
`ConfiguratorClone`'s expressions path are deleted.
`systems/shapes.{json,yaml,yml}` is the seventh: `ShapesConfigWriter.Write(packagePath, document)`
reads the document as the loader reads the file, then holds that read to `Validate`, the rules the
typed write always enforced (a shape with no elements, an element with no drawing kind or two, a
line under 2 points, a polygon under 3, a radius, a size or a stroke width of zero, a reference to no
shape or to itself, an opacity outside 0 to 1). The loader reads every one of those and
`ShapeCompiler` skips them at draw time, so the refusal is the writer's own, in its own words, and
tells `IOwnPackageWrites.ShapesFile` when it does write. The typed `Write`, its YAML refusal,
`ConfiguratorClone` and the `ShapesConfig` entry of the write context are deleted.
`manifest.json` is the ninth, after the zones dataset: `ManifestWriter.Write(packagePath, document)`
reads the document as `PackageLoaderService.LoadPackage` reads the file, refuses what
`ManifestWriter.Validate` names (what the loader's validation warns of, and a map layer with no
name, no source or a type other than geojson), and tells `IOwnPackageWrites.ManifestFile`. The
loader reads `manifest.json` and nothing else, so a YAML document is refused. The manifest never
had a typed Configurator writer; the typed write its two run-time writers shared
(`SaveManifestLastActiveProfile`, `SaveManifestPlugins`) is replaced by `Package/ManifestKeyPatch`,
which sets one key in the file's own text; the launcher's four writers (`IgnorePathService`,
`ProviderUpdater`, `LocalPackageLinker`, `PackageDeletionService.ConvertRemoteToLocal`) set their
keys the same way, and `ManifestIsNeverWrittenWholeTests` fails a file in `src/` that serialises
`PackageManifest`. An update leaves the manifest the provider served on disk, with those keys set
in it. So a new key the client writes is added in three places, or an update or a save loses it:
`Package/ManifestClientKeys.All`, the Configurator's `ManifestFields.WrittenByTheClient` (a test
holds the two equal), and `Package/CarriedManifestSettings` when it is a controller's setting that
must outlive an update or a reinstall. These writers and the radar's profile save never refuse for
a comment or a trailing comma where the key or item goes: they remove it from that one container
(`PackageDocument.WithoutWhatBlocks`) and log a Warning. A Configurator section does not: its
draft keeps the refusal to show.
A profile (`profiles/**/*.stp`, and its local copy under the data root) is the tenth:
`ProfileStorageService.Write(packagePath, namespace, profile, document, target)` reads the document
as the loader reads a profile, refuses one with no name, no map or a window area of one to three
edges, writes the document's bytes as the local copy, the package file or both, and tells
`IOwnPackageWrites.ProfileFile` for each file written. `Promote` copies the local copy's bytes over
the package file; `RevertToPackage` and the two deletes remove a file and end in `ProfileFile` or
`ProfileFileRemoved`. The typed `Save` is deleted. Consequences
for a new lists, policy, targets, labels, mapstyle, expressions, shapes, manifest or profile field:

- **A field the client model does not know survives every save**, with its comments, key order,
  quoting, rule blocks and line endings. There is no erase-on-save hazard and no
  `ReformatNotice` for this file.
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
labels.json  mapstyle.yaml  policy.json  targets.json
$ ls @sectorsrc/UK-Sector-File/package/systems
default  expressions.json  gatwick-smr  lgw  lhr  'lists copy.yaml'  lists.yaml  node  sco  shapes.json  smr  stc
```

`@sectorsrc/LFXX-Sector-File` is identical in shape: `mapstyle.yaml` per system, `lists.yaml` at
the root. A mapstyle saves in either format (§4a), so a new mapstyle field is edited in the
Configurator for both shipping sector files. `lists.yaml` saves too, as does a targets, a labels,
an expressions or a shapes file in either format. The four LFXX `labels.json` files are in an older layout the client no longer reads (a
section holding bare row grids in place of `labels`): the Tags section opens them read-only and
says so; they are converted by hand.

Two files are JSON only: the manifest, because the loader reads `manifest.json` and nothing else,
and a profile, which is a `.stp`. The read-only banner
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

Three rules every section follows (`src/NeoRadar/CLAUDE.md` § Configurator):

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

**A policy field is one declaration too.** `Sections/PolicyFields.cs` declares the policy schema:
`OfPolicy` (each field by its path from the top of the file), `OfKind(kind)` (the three maps keyed
by safety net kind), `Tables` (`RowsDeclaration`s: a list of rows such as `safetyNets.stca.regions`,
or a map of rows by key such as `runwayMonitoring.runways`) and `NotEdited`. The steps are the
three above with `policy.schema.json`, `PolicyFieldsSchemaTests` and
`PolicyOneEditOnTheRealFileTests`. Three things are particular to policy:

- **A number carries its unit in its label and takes the schema's range.** `PolicyFieldsSchemaTests`
  holds each declared minimum, maximum, exclusive minimum, whole-number flag and absent-key default
  to the pinned schema, and fails a number whose key names a unit (`Nm`, `Ft`, `S`, `Kts`, `Fpm`,
  `Deg`) that its label does not show.
- **A section that is in force by being written is declared `FieldKind.Block`**
  (`runwayMonitoring`, `runwayMonitoring.approachFunnel`, `safetyNets.stca` and its `cflLeave` and
  `finalApproach`, `safetyNets.tct` and its `stateVector`). Clearing the last setting inside one
  leaves the empty block, where any other map goes with its last key (`WrittenBlocks`). A new
  section whose reader tells absent from empty must be declared so, or clearing its last setting
  switches it off.
- **A name list the reader spells only inside its own switch** is written once in `PolicyFields`
  and held to the schema's `enum` and to what `SystemPolicies.Resolve` accepts
  (`EveryNameOfEveryPicker_IsTakenByThePolicyReader`). Kinds, severities, attention states and
  sound ids are read from Core.

**A targets field is one declaration as well.** `Sections/TargetFields.cs` declares one variant
(`OfVariant`, the path under the variant) for all four lists, and `NotEdited` the lists and
containers. The steps are the three above with `targets.schema.json`, `TargetFieldsSchemaTests`
and `TargetsOneEditOnTheRealFileTests` (which drives the new field on the UK `default` and `lhr`
files with no further code). Three things are particular to targets:

- **A number's absent-key default is held to the reader as well as the schema**
  (`EveryNumberTheReaderGivesADefault_ShowsThatDefaultWhenAbsent`): add the new number to that
  test's table from the code that draws it, and give it a unit in its label where the schema
  gives it in metres or its key ends in `Ms`.
- **A selector list the client reads empty as absent is declared `EmptyIsAbsent`** (and
  `AbsentChoices` where absent is not every name), so no edit writes `[]` and an authored `[]`
  shows what it reads as. `Sections/UnreachableVariants` must learn any new selector, or its
  never-drawn marker lies.
- **A nested block is a plain container unless the reader tells absent from empty.**
  `primaryPlotSynthesis` and `historyTrailShape` are excused in `NotEdited` with that reason; a
  block that is in force by being written is `FieldKind.Block`, as in policy.

**A labels field is one declaration, in the owner it belongs to.** `Sections/LabelFields.cs`
declares the file: `OfRoot` (the font scale and the altitude format), `OfSection` (a section's
`tagPositioning`), `OfLabelVariant`, `OfStyleVariant`, and `NotEdited` for the lists and
containers; a tag item's fields are `Sections/TagItemFields.Fields`, the one list a list column
places under `tagItem` too. The steps are the three above with `labels.schema.json`,
`LabelFieldsSchemaTests` (and `TagItemFieldsSchemaTests` for an item field) and
`LabelsOneEditOnTheRealFileTests`, which drives the new field through the Tags section on the UK
`default` and `lhr` files with no further code; `FieldClearedBackToAbsentTests` sets and clears
it where no owner writes it. Particular to labels:

- **The section is parts over one draft, each with its owner's path.** `LabelsDraft` is the
  plumbing; `LabelOwnerFieldsViewModel` is one owner's editors; `TagVariantListViewModel` a
  section's label variants or style variants; `TagGridViewModel` a label variant's rows and the
  selected item. A new owner is a declaration list and one `LabelOwnerFieldsViewModel`.
- **A tag item field reaches Lists as well**, unless `ListFields` filters it out; move
  `ListColumnFieldsOrderTests` when it does.
- **A new selector of a label or style variant is taught to `Sections/UnreachableVariants`**
  (`VariantSelectors`), or the never-drawn marker lies.
- **What an item reads in the preview is a sample, not a field**: it comes from
  `OfferedName.Sample` and `.Options` and is never written (`Preview/TagPreviewSamples`).

**A mapstyle field is one declaration too.** `Sections/MapStyleFields.cs` declares the file:
`OfBlocks` (each field by its path from the top of the file), `OfLayer` (what one layer style
holds, placed under `layerStyles` and the layer's source with `UnderKeys`), the four style lists
`LineStyle`, `FillStyle`, `PointStyle` and `TextStyle` (declared once, placed under a layer and
under `routeDraw`), `Pages` (the ten pages) and `NotEdited` (each property nothing reads, or a
container, with its reason). The steps are the three above with `mapstyle.schema.json`,
`MapStyleFieldsSchemaTests` and `MapStyleOneEditOnTheRealFileTests` (which sets and clears the new
field on the eight UK files with no further code). Particular to mapstyle:

- **A property is declared only if something reads it.** A text style key the layer label or the
  route draw's fix label never reads is excused in `NotEdited`, and
  `ExcusedLeaves_AreTextStylePropertiesNoReaderOfTheirOwnerReads_AndAMapLayersSprite` holds each
  excuse to the reader; add the reader's key list beside `TextReadByALayer` when one changes.
- **A block the reader tells absent from empty is `FieldKind.Block`** (`rdf`, `stcaPairLine`, a
  layer's `pointStyle`), as in policy; `BlocksInForceByBeingWritten_AreTheOnesTheReaderTellsFromAbsent`
  holds the list.
- **A colour takes no rule, and its alpha is kept**: an authored four-part colour stays as
  written when another field is edited or its swatch changes, and a new colour is three whole
  numbers (`MapStyleColourAlphaTests`).
- **Opening a page writes nothing**; a style appears with its first setting and leaves with its
  last (`MapsSectionTests`).

**An expressions field is one declaration too.** `Sections/ExpressionFields.cs` declares the file:
`Condition` (the condition a named expression is: the whole value under its name, placed with
`OfExpression(name)`), `OfRule` (a rule's `value` and `expression`, by their path under the rule)
and `NotEdited` (the schema link and the three containers). The steps are the three above with
`expressions.schema.json`, `ExpressionFieldsSchemaTests` and `ExpressionsOneEditOnTheRealFileTests`.
Particular to expressions:

- **A new operator, join or condition form is not a field.** It is taught to `ExpressionParser`
  and to `Fields/ConditionNode` (`Operators`, `Joins`, the forms `Read` and `Write` know), which
  every section's condition editor shares, and `expressions-condition-characterisation.txt` gains
  its row (`NEORADAR_UPDATE_EXPRESSIONS_GOLDEN=1`): what the section and the bare node show, keep
  and write for it must be the same.
- **Both keys of a rule are required by the schema, so neither is cleared**: an emptied `value`
  is written `""` (`SingleEntry`, `Required`) and a rule left naming nothing is written `[]`
  (`FieldKind.References`). A new rule key the schema does not require is declared without
  `Required` and then clears to absent like any field.
- **An entry of either map is added, removed and renamed by the section, not by a field**: a new
  expression is `["AND", []]`, which the section does not save until it holds a condition; the
  last entry removed leaves `{}`, because the schema requires both maps.
- **Every name comes from `IExpressionVocabulary`**: the key picker of a comparison and the
  catalogue are `KeyReferences`, so a new catalog key or a plugin-exported name is offered with no
  edit here.

**A shapes field is one declaration too.** `Sections/ShapeFields.cs` declares the file: `OfShape`
(a shape's six fields, by their path under the shape), `Kind` (the picker of which of an element's
six keys is written), `OfElement` (`Kind` and an element's nineteen properties, by their path under
the element) and `NotEdited` (the schema link and the five containers). The steps are the three
above with `shapes.schema.json`, `ShapeFieldsSchemaTests` and `ShapesOneEditOnTheRealFileTests`
(which sets and clears the new field on every shape or element of the UK file, in JSON and in
YAML, with no further code). Particular to shapes:

- **An element field shows for the kinds that read it.** Its `AppliesTo` asks `FieldContext.Variant`,
  which is the key the element's kind is written as. A field `ShapeCompiler` does not read for a
  kind is not shown for it (a reference shows its shape, offset, scale and rotate and nothing else).
- **A new kind of element is a `FieldAlternative` of `ShapeFields.Kind`**: its key, what it is first
  written with (nothing invented: an empty list or map, and `[0, 0]` for a point), the kinds whose
  value it takes as it stands, and the keys only some kinds read (`AlsoReads`), which leave when a
  kind that does not read them is picked. It needs its geometry fields, its arm in `ShapeCompiler`
  and its rule in `ShapesConfigWriter.Validate` as well.
- **What a field shows for an absent key is what the client draws for one**: add its row to
  `WhatAFieldShowsForAnAbsentKey_IsWhatTheClientDrawsForOne`, which writes that value into a shape
  and asks `ShapeCompiler` for the same primitives. A number takes the schema's range and nothing
  narrower.
- **Two numbers are `FieldKind.Point` and a list of them `FieldKind.PointList`**, typed one pair a
  line and written one `[x, y]` a line where the list is new to the file, in the file's own layout
  where it is not.
- **The section's table gains the row**: `shapes-characterisation.txt` holds what every field of a
  shape and of each kind offers and writes (`NEORADAR_UPDATE_SHAPES_GOLDEN=1`).
- **A property that names a shape offers the shapes being edited.** `ConfiguratorVocabulary.ShapeNames`
  given the field's context reads `EditedPackageShapes`, which the Shapes section reports to, so a
  shape is offered to a target variant before it is saved; a new shape-naming property takes that
  as its `Choices`.

**A zones property is one declaration too.** `Sections/ZoneFields.cs` declares the dataset:
`OfZone` (the four properties of a zone the client reads, by their path under the zone:
`properties.tags`, `.id`, `.floor`, `.ceiling`) and `NotEdited` (every other schema property with
its reason: the file's `type`, `name`, `crs` and `bbox`, the list of features, a feature's `type`,
`id`, `bbox`, `geometry` and `properties` map). The steps are the three above with
`@schemas/datasets/zones.schema.json` (pinned as `Fixtures/zones.schema.json`, held to the
repository's by `ZonesSchemaPinTests`), `ZoneFieldsSchemaTests` and
`ZonesOneEditOnTheRealFileTests` (the UK `zones.geojson`, pinned beside the system files).
Particular to zones:

- **Geometry is never edited and no zone is added, removed or moved.** A new property of a zone
  is a declaration under `properties`; a property of the geometry, of the feature or of the file
  is excused in `NotEdited` and kept byte for byte, as is any property the schema does not name
  (a zones file listed in `mapLayers` carries its layer styling there).
- **The parser leg is two files.** `Package/ZonesDataset.cs` (`ZoneProperties`) deserialises the
  property and `Sectors/ZoneIndex.cs` decides what a zone is built with; a property only the
  first reads is read and ignored.
- **The writer follows the loader, the section follows the schema.** `ZonesDatasetWriter` refuses
  by name what `ZoneIndex` would skip a zone for in its properties (no tags, a tag holding a
  space, a ceiling below the floor) and a bound the loader cannot read; it does not refuse a tag
  off the schema's pattern or a tag listed twice, which the loader takes. The tags editor is the
  stricter half (`WordPattern`, `DistinctWords`, `Required`), so no edit made in the section puts
  one in the file. A new rule the loader enforces goes in the writer; one only the schema states
  goes in the declaration.
- **A tag is offered from where it is read.** The tags box offers the tags the draft already uses
  and the zone tags the stored systems' resolved policies read
  (`ConfiguratorVocabulary.ZoneTagsThePoliciesRead`). A new policy key that names a zone tag adds
  its line there, or the tag is not offered.
- **A package with no zones file is not given one**: the section says so and the writer refuses.

**A manifest property is one declaration too.** `Sections/ManifestFields.cs` declares the file:
`OfManifest` (name, version, description and the six altitude format fields, by their path from the
top of the file), `FontRows` (the fonts as rows of alias and file), `OfLayer` (the 26 fields of a
map layer, by their path under the layer; under `defaultStyle` they are `MapStyleFields.OfLayer`,
because the manifest's default style and a mapstyle's layer style are merged and read by one
reader) and `NotEdited` (every other schema property with its reason). The steps are the three
above with `@schemas/package/manifest.schema.json` (pinned as `Fixtures/manifest.schema.json`, held
to the repository's by `ManifestSchemaPinTests`), `ManifestFieldsSchemaTests` and
`ManifestOneEditOnTheRealFileTests` (the manifests of the built UK and LFXX packages, pinned beside
the system files). Particular to the manifest:

- **A key the client writes while the package is in use is never a field.** `lastActiveProfile`,
  `plugins`, `ignorePaths`, `remoteSource`, `installedFiles` and `lastOpened` are
  `ManifestFields.WrittenByTheClient`: excused in `NotEdited` as the client's where the schema
  names them, and a save takes each from the file as it is on disk then, because the client
  patches them under an open Configurator. A new key the client writes at run time is added to
  that list and written through `Package/ManifestKeyPatch` (one key set in the file's own text),
  never by serialising `PackageManifest` over the file.
- **Identity is kept, not edited.** `id`, `namespace` and `createdAt` have no editor: the local
  profiles folder and the server scope follow the namespace.
- **The writer follows the loader's validation, and adds the layer rules the validator never
  reaches.** `ManifestWriter.Validate` refuses, in the model's own words, a manifest with no id,
  name, version, namespace or createdAt and a centerPoint that is not two numbers, and by its
  place and name a layer with no name, no source or a type other than geojson. A new rule the
  loader enforces goes there.
- **A layer field under `defaultStyle` is a mapstyle layer field.** Declare it in
  `MapStyleFields.OfLayer` and it reaches the manifest with no second declaration, unless the
  manifest schema does not name it (`textWeight`, `textSharpness`), in which case
  `ManifestFields.InTheManifestSchema` leaves it out until the schema does.
- **A new layer and a new font are written with the keys the schema requires and nothing chosen
  for the author** (`ManifestFields.NewLayer`, `RowsDeclaration.NewRow`); the writer refuses a
  layer until it has a name and a source.
- **The layers being edited reach Map Style before a save** through
  `Vocabulary/EditedPackageManifest`, which the Manifest section reports to. A new section that
  lists or offers the manifest's layers reads it, and falls back to the stored manifest.

**A profile property is one declaration too.** `Sections/ProfileFields.cs` declares the file:
`OfProfile` (the seventeen properties the section edits, by their path from the top of the file)
and `NotEdited` (every other schema property with its reason). The steps are the three above with
`@schemas/profile.schema.json` (pinned as `Fixtures/profile.schema.json`, held to the repository's
by `ProfileSchemaPinTests`), `ProfileFieldsSchemaTests` and `ProfilesOneEditOnTheRealFileTests`
(the five egxx profiles pinned in `tests/NeoRadar.Core.Tests/Package/Documents/PinnedProfiles`).
Particular to a profile:

- **What the controller sets from the radar is never a field.** `map.items` (with each row's
  `show`, which Map Edit sets to force an automatic item off through
  `IProfileStore.SetItemOverride`), `map.hideTags` and `map.showTags` (Map Edit's map data
  switches, `IProfileStore.SetTagShown`), the three filter switches, the speed vector, the hidden
  tag groups and the related profiles are excused in `NotEdited` as the controller's and kept as written. A new property the radar's own menus set
  is excused the same way, and must be a property of `Profile`, copied in `ProfileCopy` and
  compared in `ProfileFileDifference`, or the radar's save never writes it (§4).
- **A new property an author sets is declared, and still needs the model property** for the
  client to read it and for the radar's save to keep it.
- **A profile has two files.** The draft is of the file the stores read (the local copy, else the
  package file) and a save writes its bytes to the target picked. The writer's refusals are in
  `ProfileStorageService.Check`; a new rule the loader enforces goes there.
- **A coordinate is declared `EveryDigit`**, so its box shows every digit the file writes; a number
  with a few decimals is not.
- **A property required by the schema all the way down is declared `Required`**
  (`AFieldIsRequired_ExactlyWhenTheSchemaRequiresItAndEveryMapAboveIt`); every other one clears
  to absent. The four edges of the window area clear one at a time and the writer refuses a save
  that leaves only some.

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
- [ ] Rollout path written, all five lines, checked against both live sector files.
