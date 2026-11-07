# The Configurator declaration of a field, file by file

Section numbers (§) refer to the skill's SKILL.md.

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
  (`runwayMonitoring`, `runwayMonitoring.approachFunnel`, `safetyNets.stca` and its `finalApproach`,
  `noCfl`, `cflLeave`, `turnTest`, `levelOffTest`, `safeCrossing`, `diverging` and `ntz`,
  `safetyNets.tct` and its `stateVector`). Clearing the last setting inside one
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
  catalogue are `KeyReferences`, so a new catalogue key or a plugin-exported name is offered with no
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
