# Extension manifest and compatibility

Every extension requires an `extension.cfg` manifest at:

```text
res://addons/gator_model_studio/extensions/installed/<extension_id>/extension.cfg
```

The package must be a direct child of `installed/`, and the folder name must exactly match the lowercase manifest `id`. For example, `id="example.mesh_tools"` must use the folder `installed/example.mesh_tools/`.

## `[extension]`

| Key | Required | Default | Meaning |
|---|---:|---|---|
| `id` | Yes | — | Stable lowercase package ID containing only letters, digits, dots, underscores, and hyphens. Use namespaced text such as `studio.tool_name`. It must match the package folder name. |
| `name` | Yes | — | User-facing extension name. |
| `version` | Yes | — | Extension version using `major.minor.patch`. |
| `author` | No | Empty | Author or studio. |
| `description` | No | Empty | Short package description. |
| `entry_script` | Yes | — | GDScript path relative to the manifest, or an absolute `res://` path. A relative path is recommended. |
| `enabled` | No | `true` | Disabled manifests are ignored. |

## `[compatibility]`

| Key | Required | Default | Meaning |
|---|---:|---|---|
| `api_version` | Yes | — | Must exactly match `GMSExtensionAPI.API_VERSION`. Query `api.get_api_version()` for the active host API version. |
| `minimum_gms_version` | No | `0.0.0` | Oldest supported Gator Model Studio version. |
| `maximum_gms_version` | No | Empty | Newest supported version. Leave empty when no upper limit is known. |
| `minimum_godot_version` | No | `4.0.0` | Oldest supported Godot version. |

Incompatible extensions are skipped and the editor output states why the package was rejected. Compatibility checks compare numeric version components; pre-release labels are ignored.

Breaking API changes increment `api_version`. Additive host changes only increment the Gator Model Studio version.
