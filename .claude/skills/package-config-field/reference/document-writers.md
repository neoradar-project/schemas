# Each writer of a file edited as a document

Section numbers (§) refer to the skill's SKILL.md.

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
which sets one key in the file's own text; the launcher's five writers (`IgnorePathService`,
`ProviderInstaller`, `ProviderUpdater`, `LocalPackageLinker`, `PackageDeletionService.ConvertRemoteToLocal`) set their
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
`ProfileFileRemoved`. The typed `Save` is deleted.
