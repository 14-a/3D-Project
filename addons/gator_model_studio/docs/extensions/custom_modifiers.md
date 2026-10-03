# Custom modifiers

Register a modifier with `GMSExtensionAPI.register_modifier()`.

```gdscript
api.register_modifier({
	"id": "example.raise",
	"name": "Raise",
	"tooltip": "Moves all vertices upward.",
	"order": 20,
	"parameters": [
		{
			"id": "distance",
			"label": "Distance",
			"type": "float",
			"default": 1.0,
			"min": -1000.0,
			"max": 1000.0,
			"step": 0.01,
		},
	],
	"evaluate": _evaluate_raise,
})

func _evaluate_raise(source: GMSMeshData, parameters: Dictionary) -> GMSMeshData:
	var result: GMSMeshData = source.duplicate_mesh_data()
	var distance: float = float(parameters.get("distance", 1.0))
	for index: int in result.vertices.size():
		var vertex: Vector3 = result.vertices[index]
		vertex.y += distance
		result.vertices[index] = vertex
	result.emit_changed()
	return result
```

Descriptor fields `id`, `name`, and a valid `evaluate` callable are required. `tooltip`, `order`, and `parameters` are optional. Modifier parameters use the same declarative types as modelling tools.

The evaluator must treat `source` as read-only and return valid mesh data. Duplicate the source before changing it. Returning `null` or invalid mesh data causes the stack to keep the input mesh unchanged.

Custom modifiers participate in the normal stack, live preview, save/load, undo/redo, Apply Through, export evaluation, and enable/disable controls.

Parameter data is stored in `GMSModifier.custom_parameters`. If an extension is missing, saved parameter data remains intact, the modifier is shown as unavailable, and evaluation passes the input mesh through unchanged.
