# Getting started

Create a direct child folder under `extensions/installed/`. The folder name must match the manifest ID exactly:

```text
addons/gator_model_studio/extensions/installed/example.my_extension/
├── extension.cfg
└── my_extension.gd
```

`extension.cfg`:

```ini
[extension]
id="example.my_extension"
name="My Extension"
version="1.0.0"
author="Your Name"
description="Adds a custom modelling tool."
entry_script="my_extension.gd"
enabled=true

[compatibility]
api_version=1
minimum_gms_version="0.18.5"
maximum_gms_version=""
minimum_godot_version="4.6.0"
```

`my_extension.gd`:

```gdscript
@tool
extends GMSExtension

func register_extension(api: GMSExtensionAPI) -> void:
	var error: Error = api.register_modelling_tool({
		"id": "example.my_cube",
		"name": "My Cube",
		"object_name": "My Cube",
		"tooltip": "Creates an editable cube.",
		"parameters": [],
		"generate": _create_mesh,
	})
	if error != OK:
		push_error("Could not register My Cube: %d" % error)

func _create_mesh(_parameters: Dictionary) -> GMSMeshData:
	return GMSPrimitiveFactory.create_cube()
```

The loader calls `register_extension(api)` when the addon enters the editor tree. When the addon is disabled, it calls `unregister_extension(api)` and then removes every registration owned by that extension automatically.

Extension and registration IDs must be stable, lowercase, and unique. Namespace published IDs with your studio or package name.
