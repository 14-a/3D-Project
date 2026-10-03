# Custom exporters

An exporter may support complete documents, selected mesh objects, or both.

```gdscript
api.register_exporter({
	"id": "example.mesh_json_exporter",
	"name": "Example Mesh JSON",
	"extensions": PackedStringArray(["meshjson"]),
	"filter": "*.meshjson ; Example Mesh JSON",
	"order": 20,
	"export_mesh": _export_mesh_json,
})

func _export_mesh_json(
	objects: Array[GMSModelObject],
	path: String,
	combined: bool
) -> Error:
	# Write the active object or selected objects to the res:// path.
	return OK
```

Document callback signature:

```gdscript
func export_document(document: GMSDocument, path: String) -> Error
```

Mesh callback signature:

```gdscript
func export_mesh(
	objects: Array[GMSModelObject],
	path: String,
	combined: bool
) -> Error
```

Required descriptor fields are `id`, `name`, at least one file extension, and at least one valid export callback. `filter` is generated automatically when omitted.

`combined` is `false` for **Active Object** and `true` for **Selected Objects Combined**. The callback receives original model objects. Call `object.get_evaluated_mesh_data()` when enabled modifiers must be included, and apply object transforms when a combined format requires world-space geometry.

Return a Godot `Error` value. Registered filters are added to the appropriate export dialogs automatically. Extension exporters are checked before built-in exporters for matching suffixes, so use a unique file extension unless overriding built-in handling is intentional.
