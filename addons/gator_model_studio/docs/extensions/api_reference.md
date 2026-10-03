# Public API reference — version 1

## `GMSExtension`

Base class for extension entry scripts.

```gdscript
func register_extension(api: GMSExtensionAPI) -> void
func unregister_extension(api: GMSExtensionAPI) -> void
```

`unregister_extension` is optional. After it returns, the API removes every registration owned by the extension.

## `GMSExtensionAPI`

Constants:

```gdscript
GMSExtensionAPI.API_VERSION: int
```

Methods:

```gdscript
func register_modelling_tool(descriptor: Dictionary) -> Error
func register_modifier(descriptor: Dictionary) -> Error
func register_importer(descriptor: Dictionary) -> Error
func register_exporter(descriptor: Dictionary) -> Error
func unregister_all() -> void
func get_extension_id() -> String
func get_api_version() -> int
func get_host_version() -> String
```

Check every registration result. Invalid descriptors return `ERR_INVALID_PARAMETER`; duplicate registration IDs return `ERR_ALREADY_EXISTS`.

## Public data classes

Extensions may create and inspect:

- `GMSMeshData`: editable vertices, polygon faces, UV corners, custom normals, seams, creases, loose edges, smoothing flags, and face-material indices
- `GMSModelObject`: object transform, materials, modifiers, visibility, locking, and collision settings
- `GMSDocument`: model object collection
- `GMSModifier`: built-in or custom modifier state

Treat values passed into modifier and exporter callbacks as read-only unless the callback contract explicitly states otherwise. Duplicate resources before destructive changes.

## Registries

The registry classes are public for discovery and advanced tooling:

- `GMSModelToolRegistry`
- `GMSModifierRegistry`
- `GMSImporterRegistry`
- `GMSExporterRegistry`

Normal extensions should register through `GMSExtensionAPI`, which records ownership and guarantees clean unregistration.

## ID rules

- Package and registration IDs are normalized to lowercase.
- IDs must not be empty.
- IDs must remain stable across updates.
- Duplicate registration IDs return `ERR_ALREADY_EXISTS`.
- Published IDs should be namespaced, such as `blackwater_gator.procedural_gear`.
- The package folder must exactly match its manifest ID.

## Lifecycle

1. The addon scans direct child folders of `extensions/installed/` for `extension.cfg`.
2. The package folder name is checked against the manifest ID.
3. The manifest is parsed and checked for compatibility.
4. The entry script is instantiated.
5. `register_extension(api)` is called.
6. Gator Model Studio builds menus and file filters from the registries.
7. On addon shutdown, `unregister_extension(api)` is called, followed by automatic removal of all owned registrations.

Packages are loaded in path order. Extensions must not depend on another extension having registered first.
