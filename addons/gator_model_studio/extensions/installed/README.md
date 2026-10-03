# Installed extensions

All loadable Gator Model Studio extensions belong here as direct child folders:

```text
res://addons/gator_model_studio/extensions/installed/<extension_id>/
```

Each folder must contain `extension.cfg` at its root, and the folder name must exactly match the lowercase `id` in that manifest. Nested extension packages are not scanned.

The bundled reference package is:

```text
blackwater_gator.procedural_gear/
```

Restart the editor or disable and re-enable Gator Model Studio after installing, removing, or changing an extension.
