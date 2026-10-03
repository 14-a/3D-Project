@tool
extends EditorPlugin

const GATOR_PANEL_SCENE_PATH: String = "res://addons/gator_sprite_studio/core/gator_sprite_studio_panel.tscn"
const PANEL_LAYOUT_REVISION: int = 85

var main_panel: GatorSpriteStudioPanel
var retained_session_state: Dictionary = {}

func _enter_tree() -> void:
	_create_main_panel()
	_make_visible(false)

func _exit_tree() -> void:
	if main_panel != null:
		main_panel.save_recovery_now()
		main_panel.queue_free()
		main_panel = null

func _has_main_screen() -> bool:
	return true

func _make_visible(is_visible: bool) -> void:
	if is_visible and (main_panel == null or int(main_panel.get_meta("gator_layout_revision", -1)) != PANEL_LAYOUT_REVISION):
		if main_panel != null:
			retained_session_state = main_panel.capture_session_state()
			main_panel.queue_free()
		_create_main_panel()
		if main_panel != null and not retained_session_state.is_empty():
			main_panel.restore_session_state(retained_session_state)
	if main_panel != null:
		main_panel.visible = is_visible
		main_panel.set_shortcuts_enabled(is_visible)

func _create_main_panel() -> void:
	var panel_scene: PackedScene = ResourceLoader.load(GATOR_PANEL_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if panel_scene == null:
		push_error("Gator Sprite Studio could not load its main panel scene.")
		return
	main_panel = panel_scene.instantiate() as GatorSpriteStudioPanel
	main_panel.set_meta("gator_layout_revision", PANEL_LAYOUT_REVISION)
	EditorInterface.get_editor_main_screen().add_child(main_panel)

func _get_plugin_name() -> String:
	return "GSS"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/gator_sprite_studio/icon.svg")
