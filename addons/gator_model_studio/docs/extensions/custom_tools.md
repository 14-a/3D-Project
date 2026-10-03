# Custom modelling tools

Register a modelling tool with `GMSExtensionAPI.register_modelling_tool()`.

```gdscript
api.register_modelling_tool({
	"id": "example.custom_plane",
	"name": "Custom Plane",
	"object_name": "Custom Plane",
	"category": "Examples",
	"tooltip": "Creates a configurable plane.",
	"order": 20,
	"parameters": [
		{
			"id": "size",
			"label": "Size",
			"type": "float",
			"default": 2.0,
			"min": 0.01,
			"max": 1000.0,
			"step": 0.01,
		},
	],
	"generate": _generate_plane,
})
```

Descriptor fields:

- `id`, `name`, and a valid `generate` callable are required.
- `object_name` controls the new object's default name.
- `tooltip` and `icon` affect the Add menu entry.
- `category` and `order` control registry sorting.
- `parameters` generates the creation dialog.

The `generate` callable receives one `Dictionary` containing current parameter values and must return valid `GMSMeshData`. The returned geometry becomes a normal editable object and is inserted through Gator Model Studio history, so creation supports undo and redo.

Supported declarative parameter types:

- `int`: `default`, `min`, `max`, `step`, and optional `tooltip`
- `float`: `default`, `min`, `max`, `step`, and optional `tooltip`
- `bool`: `default` and optional `tooltip`
- `enum`: integer `default`, an `options` array, and optional `tooltip`
- `string`: string `default` and optional `tooltip`

Registered tools appear in the Extensions section of the Object-mode **Shift+A** menu. The bundled Procedural Gear package is the full reference implementation.
