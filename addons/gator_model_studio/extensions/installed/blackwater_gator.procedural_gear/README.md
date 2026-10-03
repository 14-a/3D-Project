# Procedural Gear reference extension

Installed package ID and location:

```text
blackwater_gator.procedural_gear
res://addons/gator_model_studio/extensions/installed/blackwater_gator.procedural_gear/
```

This enabled package uses the same loader, manifest, compatibility checks, registries, and unload process as third-party extensions. It demonstrates:

- `extension.cfg` metadata and compatibility
- an adjustable modelling tool
- declarative parameter controls
- generation of editable `GMSMeshData`
- a non-destructive custom modifier
- registration error handling
- automatic cleanup when the addon is disabled

Open Gator Model Studio, enter Object mode, and choose **Shift+A → Procedural Gear**. The **Radial Scale** modifier appears in the normal modifier list.

To use it as a template, duplicate the entire package into a new direct child folder of `extensions/installed/`. Rename that folder to the new manifest ID, change all registration IDs, and update the two absolute preload paths in `procedural_gear_extension.gd` to point at the new folder.
