@tool
extends EditorPlugin

const MAIN_SCREEN_SCRIPT: Script = preload("res://addons/gator_model_studio/ui/gms_main_screen.gd")
const PLUGIN_ICON: Texture2D = preload("res://addons/gator_model_studio/icon.svg")

var _main_screen: GMSMainScreen
var _extension_loader: GMSExtensionLoader
var _requested_visible: bool = false
var _shutting_down: bool = false


func _enter_tree() -> void:
	_shutting_down = false
	_requested_visible = false
	# Let Godot finish the plugin-enable transaction before constructing the large
	# editor UI or loading extension instances. This avoids overlapping startup
	# work with Project Settings / plugin management modal state.
	call_deferred("_initialize_plugin")


func _initialize_plugin() -> void:
	if _shutting_down or not is_inside_tree() or is_instance_valid(_main_screen):
		return
	var plugin_version: String = get_plugin_version()
	_extension_loader = GMSExtensionLoader.new(plugin_version)
	for message: String in _extension_loader.load_all():
		print("Gator Model Studio: %s" % message)

	_main_screen = MAIN_SCREEN_SCRIPT.new() as GMSMainScreen
	if _main_screen == null:
		push_error("Gator Model Studio could not create its main screen.")
		return

	_main_screen.configure_plugin_metadata(plugin_version, GMSExtensionAPI.API_VERSION)
	_main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var editor_main_screen: Control = EditorInterface.get_editor_main_screen()
	if editor_main_screen == null:
		push_error("Gator Model Studio could not access Godot's main editor screen.")
		_main_screen.free()
		_main_screen = null
		if _extension_loader != null:
			_extension_loader.unload_all()
			_extension_loader = null
		return
	editor_main_screen.add_child(_main_screen)
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_screen.visible = _requested_visible


func _disable_plugin() -> void:
	if is_instance_valid(_main_screen):
		_main_screen.save_recovery_copy()


func _exit_tree() -> void:
	_shutting_down = true
	# Free the main screen synchronously so its _exit_tree() can stop timers,
	# workers and editor signal connections before extension registries unload.
	# queue_free() here can leave the previous screen alive into the next frame,
	# which is unsafe if the plugin is disabled/re-enabled quickly.
	if is_instance_valid(_main_screen):
		var parent: Node = _main_screen.get_parent()
		if parent != null:
			parent.remove_child(_main_screen)
		_main_screen.free()
	_main_screen = null
	if _extension_loader != null:
		_extension_loader.unload_all()
	_extension_loader = null


func _has_main_screen() -> bool:
	return true


func _make_visible(is_visible: bool) -> void:
	_requested_visible = is_visible
	if is_instance_valid(_main_screen):
		_main_screen.visible = is_visible


func _get_plugin_name() -> String:
	return "GMS"


func _get_plugin_icon() -> Texture2D:
	return PLUGIN_ICON


func _get_unsaved_status(for_scene: String) -> String:
	if not for_scene.is_empty() or not is_instance_valid(_main_screen):
		return ""
	if _main_screen.has_unsaved_changes():
		return "Gator Model Studio has unsaved model changes."
	return ""


func _save_external_data() -> void:
	if is_instance_valid(_main_screen):
		_main_screen.save_external_data()
