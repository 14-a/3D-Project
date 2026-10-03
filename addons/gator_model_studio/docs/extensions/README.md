# Gator Model Studio Extension API

The installed Gator Model Studio version and Extension API version are supplied by the host plugin at runtime. Extensions can add modelling tools, non-destructive modifiers, mesh importers, and document or mesh exporters without editing the addon source.

All loadable extensions use one installation contract:

```text
res://addons/gator_model_studio/extensions/installed/<extension_id>/
```

The extension must be a direct child of `installed/`, its folder name must exactly match the lowercase `id` in `extension.cfg`, and the manifest must be at the folder root. Nested extension packages are not scanned.

Restart the editor or disable and re-enable Gator Model Studio after installing, removing, or changing an extension.

Documentation:

- [Getting started](getting_started.md)
- [Manifest and compatibility](extension_manifest.md)
- [Custom modelling tools](custom_tools.md)
- [Custom modifiers](custom_modifiers.md)
- [Custom importers](custom_importers.md)
- [Custom exporters](custom_exporters.md)
- [API reference](api_reference.md)

The enabled reference extension ships at:

```text
res://addons/gator_model_studio/extensions/installed/blackwater_gator.procedural_gear/
```
