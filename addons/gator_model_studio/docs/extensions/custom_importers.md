# Custom importers

Register an importer with `GMSExtensionAPI.register_importer()`.

```gdscript
api.register_importer({
	"id": "example.mesh_json_importer",
	"name": "Example Mesh JSON",
	"extensions": PackedStringArray(["meshjson"]),
	"filter": "*.meshjson ; Example Mesh JSON",
	"order": 20,
	"import": _import_mesh_json,
})

func _import_mesh_json(path: String) -> Array[GMSModelObject]:
	var objects: Array[GMSModelObject] = []
	# Parse the res:// file and create one or more editable objects.
	return objects
```

Required descriptor fields are `id`, `name`, at least one file extension, and a valid `import` callable. `filter` is generated automatically when omitted. Extensions may be written with or without a leading dot; they are normalized to lowercase.

The callback receives the selected `res://` path and returns an `Array[GMSModelObject]`. Every returned object must contain valid `GMSMeshData`. Gator Model Studio normalizes names, material slots, IDs, selection, and undo/redo insertion.

Return an empty array when import fails and report details with `push_error()` or `push_warning()`. Keep import work linear in the amount of source geometry; do not rebuild full topology once per edge or face.

Extension importers are checked before the built-in importer for matching suffixes. Use a unique file extension unless overriding the built-in handling is intentional.
