@tool
extends RefCounted

const BACKGROUND: Color = Color("15171c")
const PANEL: Color = Color("1d2027")
const PANEL_RAISED: Color = Color("252932")
const CONTROL: Color = Color("2a2e38")
const CONTROL_HOVER: Color = Color("343a46")
const CONTROL_PRESSED: Color = Color("274c70")
const BORDER: Color = Color("3a404c")
const ACCENT: Color = Color("62a8ff")
const TEXT: Color = Color("e4e8ef")
const TEXT_MUTED: Color = Color("9ba5b5")

const TAB_ARROW_LEFT: Texture2D = preload("res://addons/gator_sprite_studio/icons/left.svg")
const TAB_ARROW_RIGHT: Texture2D = preload("res://addons/gator_sprite_studio/icons/right.svg")

static func create() -> Theme:
	var studio_theme: Theme = Theme.new()
	studio_theme.default_font_size = 13

	studio_theme.set_color("font_color", "Label", TEXT)
	studio_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.0))

	studio_theme.set_color("font_color", "Button", TEXT)
	studio_theme.set_color("font_hover_color", "Button", Color.WHITE)
	studio_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	studio_theme.set_color("font_focus_color", "Button", Color.WHITE)
	studio_theme.set_color("font_disabled_color", "Button", TEXT_MUTED.darkened(0.25))
	studio_theme.set_color("icon_normal_color", "Button", Color.WHITE)
	studio_theme.set_color("icon_hover_color", "Button", Color.WHITE)
	studio_theme.set_color("icon_pressed_color", "Button", Color.WHITE)
	studio_theme.set_color("icon_focus_color", "Button", Color.WHITE)

	studio_theme.set_color("font_color", "LineEdit", TEXT)
	studio_theme.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	studio_theme.set_color("caret_color", "LineEdit", ACCENT)
	studio_theme.set_color("selection_color", "LineEdit", ACCENT.darkened(0.35))
	studio_theme.set_color("font_color", "OptionButton", TEXT)
	studio_theme.set_color("font_color", "CheckButton", TEXT)

	studio_theme.set_stylebox("panel", "Panel", _box(BACKGROUND, BORDER, 0, 0, 0))
	studio_theme.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 1, 4, 6))
	studio_theme.set_stylebox("normal", "Button", _box(CONTROL, BORDER, 1, 3, 6))
	studio_theme.set_stylebox("hover", "Button", _box(CONTROL_HOVER, ACCENT.darkened(0.25), 1, 3, 6))
	studio_theme.set_stylebox("pressed", "Button", _box(CONTROL_PRESSED, ACCENT, 1, 3, 6))
	studio_theme.set_stylebox("focus", "Button", _outline_box(ACCENT, 1, 3))
	studio_theme.set_stylebox("disabled", "Button", _box(PANEL, BORDER.darkened(0.2), 1, 3, 6))
	studio_theme.set_stylebox("normal", "LineEdit", _box(CONTROL, BORDER, 1, 3, 6))
	studio_theme.set_stylebox("focus", "LineEdit", _box(CONTROL, ACCENT, 1, 3, 6))
	studio_theme.set_stylebox("read_only", "LineEdit", _box(PANEL, BORDER, 1, 3, 6))
	studio_theme.set_stylebox("normal", "OptionButton", _box(CONTROL, BORDER, 1, 3, 6))
	studio_theme.set_stylebox("hover", "OptionButton", _box(CONTROL_HOVER, ACCENT.darkened(0.25), 1, 3, 6))
	studio_theme.set_stylebox("pressed", "OptionButton", _box(CONTROL_PRESSED, ACCENT, 1, 3, 6))
	studio_theme.set_stylebox("focus", "OptionButton", _outline_box(ACCENT, 1, 3))

	_apply_tab_container_theme(studio_theme)
	_apply_tab_bar_theme(studio_theme)

	studio_theme.set_stylebox("panel", "PopupPanel", _box(PANEL_RAISED, BORDER, 1, 4, 8))
	studio_theme.set_stylebox("panel", "PopupMenu", _box(PANEL_RAISED, BORDER, 1, 4, 6))
	studio_theme.set_stylebox("hover", "PopupMenu", _box(CONTROL_HOVER, Color(0.0, 0.0, 0.0, 0.0), 0, 2, 4))
	studio_theme.set_stylebox("panel", "ScrollContainer", _box(BACKGROUND, Color(0.0, 0.0, 0.0, 0.0), 0, 0, 0))

	studio_theme.set_constant("separation", "HBoxContainer", 4)
	studio_theme.set_constant("separation", "VBoxContainer", 4)
	studio_theme.set_constant("h_separation", "GridContainer", 3)
	studio_theme.set_constant("v_separation", "GridContainer", 3)
	studio_theme.set_constant("outline_size", "Label", 0)
	return studio_theme

static func _apply_tab_container_theme(studio_theme: Theme) -> void:
	var control_type: StringName = &"TabContainer"
	_apply_tab_colours(studio_theme, control_type)

	studio_theme.set_stylebox("panel", control_type, _box(PANEL, BORDER, 1, 4, 6))
	studio_theme.set_stylebox("tabbar_background", control_type, _box(PANEL, BORDER, 0, 0, 0))
	studio_theme.set_stylebox("tab_unselected", control_type, _box(CONTROL, BORDER, 1, 3, 8))
	studio_theme.set_stylebox("tab_hovered", control_type, _box(CONTROL_HOVER, ACCENT.darkened(0.25), 1, 3, 8))
	studio_theme.set_stylebox("tab_selected", control_type, _box(CONTROL_PRESSED, ACCENT, 1, 3, 8))
	studio_theme.set_stylebox("tab_disabled", control_type, _box(PANEL, BORDER.darkened(0.2), 1, 3, 8))
	studio_theme.set_stylebox("tab_focus", control_type, _outline_box(ACCENT, 1, 3))

	_apply_tab_icons(studio_theme, control_type)
	studio_theme.set_constant("tab_separation", control_type, 2)
	studio_theme.set_constant("side_margin", control_type, 4)
	studio_theme.set_constant("icon_separation", control_type, 4)

static func _apply_tab_bar_theme(studio_theme: Theme) -> void:
	var control_type: StringName = &"TabBar"
	_apply_tab_colours(studio_theme, control_type)

	studio_theme.set_stylebox("tab_unselected", control_type, _box(CONTROL, BORDER, 1, 3, 8))
	studio_theme.set_stylebox("tab_hovered", control_type, _box(CONTROL_HOVER, ACCENT.darkened(0.25), 1, 3, 8))
	studio_theme.set_stylebox("tab_selected", control_type, _box(CONTROL_PRESSED, ACCENT, 1, 3, 8))
	studio_theme.set_stylebox("tab_disabled", control_type, _box(PANEL, BORDER.darkened(0.2), 1, 3, 8))
	studio_theme.set_stylebox("tab_focus", control_type, _outline_box(ACCENT, 1, 3))
	studio_theme.set_stylebox("button_highlight", control_type, _box(CONTROL_HOVER, ACCENT.darkened(0.25), 1, 3, 4))
	studio_theme.set_stylebox("button_pressed", control_type, _box(CONTROL_PRESSED, ACCENT, 1, 3, 4))

	_apply_tab_icons(studio_theme, control_type)
	studio_theme.set_constant("tab_separation", control_type, 2)
	studio_theme.set_constant("h_separation", control_type, 4)

static func _apply_tab_colours(studio_theme: Theme, control_type: StringName) -> void:
	studio_theme.set_color("font_unselected_color", control_type, TEXT_MUTED)
	studio_theme.set_color("font_selected_color", control_type, Color.WHITE)
	studio_theme.set_color("font_hovered_color", control_type, Color.WHITE)
	studio_theme.set_color("font_disabled_color", control_type, TEXT_MUTED.darkened(0.25))
	studio_theme.set_color("icon_unselected_color", control_type, TEXT_MUTED)
	studio_theme.set_color("icon_selected_color", control_type, Color.WHITE)
	studio_theme.set_color("icon_hovered_color", control_type, Color.WHITE)
	studio_theme.set_color("icon_disabled_color", control_type, TEXT_MUTED.darkened(0.25))
	studio_theme.set_color("drop_mark_color", control_type, ACCENT)

static func _apply_tab_icons(studio_theme: Theme, control_type: StringName) -> void:
	studio_theme.set_icon("decrement", control_type, TAB_ARROW_LEFT)
	studio_theme.set_icon("decrement_highlight", control_type, TAB_ARROW_LEFT)
	studio_theme.set_icon("increment", control_type, TAB_ARROW_RIGHT)
	studio_theme.set_icon("increment_highlight", control_type, TAB_ARROW_RIGHT)

static func _outline_box(border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

static func _box(background_color: Color, border_color: Color, border_width: int, radius: int, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	return style
