# Gator Sprite Studio extension example

This folder contains the manually loaded `example_extension.gd`, which adds a **Refresh Report** command and a **Sprite Report** panel.

The bundled official extensions, including the Aseprite importer, are under `extensions_official/` and load automatically.

## Try the example

1. Open **Gator Sprite Studio** in the Godot editor.
2. Click **Load Extension...** in the top command bar.
3. Select `addons/gator_sprite_studio/extensions_demo/example_extension.gd`.
4. Use **Refresh Report** in the toolbar, Extensions menu, or with `Ctrl+Shift+R`.
5. Inspect the **Sprite Report** tab in the right sidebar.

## Create an extension

Create a `.gd` file anywhere inside your Godot project and inherit from `GatorSpriteExtension`:

```gdscript
@tool
extends GatorSpriteExtension

var change_count: int = 0

func get_extension_manifest() -> Dictionary:
	return {"id": "com.your_studio.my_tool", "name": "My Tool", "version": "1.0.0", "dependencies": PackedStringArray()}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	super.on_extension_loaded(extension_context)
	context.register_command("hello", "Hello", _say_hello, true, "CTRL+ALT+H")

func on_document_ready(sprite_document: GatorSpriteDocument) -> void:
	print("Opened %s" % sprite_document.document_title)

func on_tool_changed(tool_mode: GatorCanvas.ToolMode) -> void:
	print("Tool: %s" % GatorCanvas.ToolMode.keys()[tool_mode])

func on_pixels_changed(sprite_document: GatorSpriteDocument, frame_index: int, layer_index: int) -> void:
	change_count += 1

func _say_hello() -> void:
	context.notify("Hello from My Tool")
```

All extension scripts must include `@tool`, inherit `GatorSpriteExtension`, and use static type annotations.

## Available callbacks

| Callback | When it runs |
| --- | --- |
| `on_document_ready(sprite_document)` | A document is created, loaded, or the extension is first loaded. |
| `on_tool_changed(tool_mode)` | The artist selects a drawing tool. |
| `on_pixels_changed(sprite_document, frame_index, layer_index)` | A drawing edit is committed. |
| `before_edit(edit_context)` | Before a canvas edit. Return `false` or call `edit_context.cancel()` to veto it. |
| `on_unloaded()` | Before registered UI and dialogs are destroyed. |

`sprite_document` provides the project data: canvas size, layers, frames, palettes, tags, slices, tileset, and tilemap. Be deliberate when modifying it: extensions execute inside the Godot editor and can change the active document.

## Context API

`context` is available after `on_extension_loaded` and provides the supported host API:

- `register_command(id, title, callable, toolbar, shortcut)` for Extensions-menu commands, optional toolbar buttons, and shortcuts.
- `register_panel(id, title, control)` for panels inside the Extensions tab.
- `register_sidebar_panel(id, title, control)` and `focus_sidebar_panel(id)` for prominent top-level sidebar tabs.
- `show_open_file_dialog`, `show_save_file_dialog`, and `show_folder_dialog` for project-aware dialogs.
- `notify(message, is_error)` for status feedback.
- `get_document`, active frame/layer getters, selected-frame access, `set_active_cell`, and `replace_document` for document navigation and importers.
- `has_selection`, `get_selection_bounds`, `set_selection_mask`, `copy_selection`, `paste_selection`, and `clear_selection` for selection/clipboard work.
- `get_document_brush_image()` for a cropped selection or visible active-frame image, plus custom-brush image/scale access and `modify_custom_brush_stamp()` for brush libraries and per-stamp variation. A stamp modifier may return `use_source_colors = true` to preserve the brush image colours instead of tinting its alpha mask.
- `refresh_document(mark_dirty)` after direct document-resource changes.
- `begin_undo_transaction`, `commit_undo_transaction`, `undo`, and `redo` for history-aware document changes.
- `export_assets(directory, name, frames, sheet, sprite_frames)` for the built-in PNG/SpriteFrames exporter.

Every extension needs a stable manifest `id`; optional `dependencies` names are checked at load time. Keep extension UI inside `context` registrations so it is safely cleaned up when unloaded.
