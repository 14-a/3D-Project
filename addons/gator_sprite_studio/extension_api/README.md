# Gator Sprite Studio Extension API

This folder contains the public base classes used by bundled and third-party GSS extensions.

- `gator_sprite_extension.gd` — extension lifecycle and callback base class.
- `gator_sprite_extension_context.gd` — supported access to GSS documents, UI registration, dialogs, selections, undo, brushes, and exports.

Third-party extensions should inherit `GatorSpriteExtension` by class name rather than depending on internal files under `core/`.
