@tool
extends EditorPlugin

const MAIN_SCREEN_SCRIPT_PATH: String = "res://addons/gator_audio_studio/ui/gator_audio_studio_main.gd"
const ExtensionManager: GDScript = preload("res://addons/gator_audio_studio/audio/extension_manager.gd")
const SUPPORT_POPUP_SETTING: String = "gator_audio_studio/support_popup_shown"
const SUPPORT_URL: String = "https://ko-fi.com/blackwatergatorstudios"

var _main_screen: Control
var _main_content: Control
var _support_dialog: AcceptDialog


func _enter_tree() -> void:
	# Extension discovery only loads small extension entry scripts and component metadata.
	# Heavy GAS workspaces remain lazy-loaded below.
	ExtensionManager.reload_all()
	# Keep plugin enable/disable cheap. The large GAS script/UI graph is loaded only
	# when the user actually opens the GAS main screen.
	_main_screen = Control.new()
	_main_screen.name = "GatorAudioStudio"
	_main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_main_screen.hide()
	_schedule_support_popup_if_needed()


func _exit_tree() -> void:
	ExtensionManager.unload_all()
	if is_instance_valid(_support_dialog):
		_support_dialog.queue_free()
	_support_dialog = null
	if is_instance_valid(_main_screen):
		_main_screen.queue_free()
	_main_content = null
	_main_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if not is_instance_valid(_main_screen):
		return
	if visible:
		_ensure_main_content()
	_main_screen.visible = visible


func _ensure_main_content() -> void:
	if is_instance_valid(_main_content):
		return
	var loaded: Resource = load(MAIN_SCREEN_SCRIPT_PATH)
	var script: GDScript = loaded as GDScript
	if script == null:
		push_error("Gator Audio Studio: could not load main-screen script.")
		return
	if not script.can_instantiate():
		script.reload(true)
	if not script.can_instantiate():
		push_error("Gator Audio Studio: main-screen script could not be instantiated.")
		return
	var instance: Object = script.new()
	var control: Control = instance as Control
	if control == null:
		push_error("Gator Audio Studio: main-screen script did not create a Control.")
		return
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_screen.add_child(control)
	_main_content = control



func _schedule_support_popup_if_needed() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return
	if settings.has_setting(SUPPORT_POPUP_SETTING) and bool(settings.get_setting(SUPPORT_POPUP_SETTING)):
		return
	call_deferred("_show_support_popup")


func _show_support_popup() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return
	if settings.has_setting(SUPPORT_POPUP_SETTING) and bool(settings.get_setting(SUPPORT_POPUP_SETTING)):
		return
	var base: Control = EditorInterface.get_base_control()
	if base == null:
		return
	_support_dialog = AcceptDialog.new()
	_support_dialog.title = "Gator Audio Studio"
	_support_dialog.dialog_text = ""
	_support_dialog.min_size = Vector2i(420, 190)

	var message: Label = Label.new()
	message.text = "Thank you for using Gator Audio Studio. This is a one-time message and will not appear every time you open the project. The Donate option in the Help menu opens my Ko-fi page. There you can make a standard donation, support me through the shop, or view my paid Godot development services."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(380.0, 0.0)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_support_dialog.add_child(message)

	base.add_child(_support_dialog)
	settings.set_setting(SUPPORT_POPUP_SETTING, true)
	_support_dialog.popup_centered(Vector2i(460, 250))

func _get_plugin_name() -> String:
	return "GAS"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("AudioStreamPlayer", "EditorIcons")
