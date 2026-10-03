@tool
class_name GMSRigOverlay
extends Control

const BONE_COLOR: Color = Color(0.78, 0.80, 0.86, 0.95)
const SELECTED_COLOR: Color = Color(1.0, 0.67, 0.12, 1.0)
const OUTLINE_COLOR: Color = Color(0.04, 0.045, 0.055, 0.95)
const HEAD_RADIUS: float = 4.0
const TAIL_RADIUS: float = 3.0
const BRUSH_OUTLINE_COLOR: Color = Color(0.98, 0.99, 1.0, 0.9)

var heads: PackedVector2Array = PackedVector2Array()
var tails: PackedVector2Array = PackedVector2Array()
var depths: PackedFloat32Array = PackedFloat32Array()
var names: PackedStringArray = PackedStringArray()
var selected_bone: int = -1
var show_names: bool = true
var weight_points: PackedVector2Array = PackedVector2Array()
var weight_values: PackedFloat32Array = PackedFloat32Array()
var brush_visible: bool = false
var brush_center: Vector2 = Vector2.ZERO
var brush_radius: float = 0.0
var brush_mode: int = 0
var brush_strength: float = 0.5
var animation_chain_points: PackedVector2Array = PackedVector2Array()
var animation_target: Vector2 = Vector2.ZERO
var animation_pole: Vector2 = Vector2.ZERO
var animation_show_ik: bool = false
var root_motion_path: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_bone_projection(
	new_heads: PackedVector2Array,
	new_tails: PackedVector2Array,
	new_depths: PackedFloat32Array,
	new_names: PackedStringArray,
	new_selected_bone: int
) -> void:
	heads = new_heads
	tails = new_tails
	depths = new_depths
	names = new_names
	selected_bone = new_selected_bone
	visible = not heads.is_empty()
	queue_redraw()



func set_brush_preview(new_center: Vector2, new_radius: float, new_mode: int, new_strength: float) -> void:
	brush_visible = true
	brush_center = new_center
	brush_radius = maxf(new_radius, 1.0)
	brush_mode = new_mode
	brush_strength = clampf(new_strength, 0.0, 1.0)
	queue_redraw()


func clear_brush_preview() -> void:
	if not brush_visible:
		return
	brush_visible = false
	queue_redraw()


func _brush_color() -> Color:
	match brush_mode:
		0:
			return Color(0.22, 0.75, 1.0, 0.18 + brush_strength * 0.18)
		1:
			return Color(1.0, 0.35, 0.3, 0.16 + brush_strength * 0.18)
		2:
			return Color(1.0, 0.78, 0.2, 0.16 + brush_strength * 0.18)
		3:
			return Color(0.65, 0.92, 0.45, 0.16 + brush_strength * 0.18)
		_:
			return Color(1.0, 1.0, 1.0, 0.16 + brush_strength * 0.18)


func set_animation_guides(
	chain_points: PackedVector2Array,
	target_position: Vector2,
	pole_position: Vector2,
	show_ik: bool,
	new_root_motion_path: PackedVector2Array
) -> void:
	animation_chain_points = chain_points.duplicate()
	animation_target = target_position
	animation_pole = pole_position
	animation_show_ik = show_ik
	root_motion_path = new_root_motion_path.duplicate()
	queue_redraw()


func clear_animation_guides() -> void:
	animation_chain_points.clear()
	root_motion_path.clear()
	animation_target = Vector2.ZERO
	animation_pole = Vector2.ZERO
	animation_show_ik = false
	queue_redraw()


func set_weight_projection(new_points: PackedVector2Array, new_weights: PackedFloat32Array) -> void:
	weight_points = new_points
	weight_values = new_weights
	queue_redraw()


func clear_weights() -> void:
	weight_points.clear()
	weight_values.clear()
	queue_redraw()


func clear() -> void:
	heads.clear()
	tails.clear()
	depths.clear()
	names.clear()
	selected_bone = -1
	weight_points.clear()
	weight_values.clear()
	brush_visible = false
	animation_chain_points.clear()
	root_motion_path.clear()
	animation_target = Vector2.ZERO
	animation_pole = Vector2.ZERO
	animation_show_ik = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if root_motion_path.size() >= 2:
		for point_index: int in range(1, root_motion_path.size()):
			draw_line(
				root_motion_path[point_index - 1],
				root_motion_path[point_index],
				Color(0.3, 0.92, 0.64, 0.9),
				2.0,
				true
			)
	if animation_show_ik:
		if animation_chain_points.size() >= 2:
			for point_index: int in range(1, animation_chain_points.size()):
				draw_line(
					animation_chain_points[point_index - 1],
					animation_chain_points[point_index],
					Color(0.2, 0.88, 1.0, 0.95),
					4.0,
					true
				)
		if not animation_chain_points.is_empty():
			draw_line(animation_chain_points[0], animation_pole, Color(0.75, 0.45, 1.0, 0.72), 1.5, true)
		var target_size: float = 8.0
		var target_points: PackedVector2Array = PackedVector2Array([
			animation_target + Vector2(0.0, -target_size),
			animation_target + Vector2(target_size, 0.0),
			animation_target + Vector2(0.0, target_size),
			animation_target + Vector2(-target_size, 0.0),
		])
		draw_colored_polygon(target_points, Color(0.12, 0.78, 1.0, 0.9))
		draw_polyline(PackedVector2Array([target_points[0], target_points[1], target_points[2], target_points[3], target_points[0]]), OUTLINE_COLOR, 2.0, true)
		var pole_size: float = 7.0
		var pole_points: PackedVector2Array = PackedVector2Array([
			animation_pole + Vector2(0.0, -pole_size),
			animation_pole + Vector2(pole_size, pole_size),
			animation_pole + Vector2(-pole_size, pole_size),
		])
		draw_colored_polygon(pole_points, Color(0.75, 0.45, 1.0, 0.9))
		draw_polyline(PackedVector2Array([pole_points[0], pole_points[1], pole_points[2], pole_points[0]]), OUTLINE_COLOR, 2.0, true)

	if brush_visible and brush_radius > 0.0:
		var fill_color: Color = _brush_color()
		draw_circle(brush_center, brush_radius, fill_color)
		draw_arc(brush_center, brush_radius, 0.0, TAU, 48, BRUSH_OUTLINE_COLOR, 1.5, true)
		draw_arc(brush_center, maxf(brush_radius - 2.0, 1.0), 0.0, TAU, 48, fill_color.lightened(0.2), 1.0, true)
		draw_line(brush_center + Vector2(-4.0, 0.0), brush_center + Vector2(4.0, 0.0), BRUSH_OUTLINE_COLOR, 1.0, true)
		draw_line(brush_center + Vector2(0.0, -4.0), brush_center + Vector2(0.0, 4.0), BRUSH_OUTLINE_COLOR, 1.0, true)

	for point_index: int in mini(weight_points.size(), weight_values.size()):
		var weight: float = clampf(weight_values[point_index], 0.0, 1.0)
		var low: Color = Color(0.08, 0.20, 0.95, 0.72)
		var high: Color = Color(1.0, 0.12, 0.04, 0.96)
		var color: Color = low.lerp(high, weight)
		draw_circle(weight_points[point_index], 2.2, OUTLINE_COLOR)
		draw_circle(weight_points[point_index], 1.45, color)

	var order: Array[int] = []
	for bone_index: int in heads.size():
		order.append(bone_index)
	order.sort_custom(func(a: int, b: int) -> bool:
		return depths[a] > depths[b]
	)
	for bone_index: int in order:
		if bone_index >= tails.size():
			continue
		var head: Vector2 = heads[bone_index]
		var tail: Vector2 = tails[bone_index]
		var selected: bool = bone_index == selected_bone
		var color: Color = SELECTED_COLOR if selected else BONE_COLOR
		draw_line(head, tail, OUTLINE_COLOR, 7.0, true)
		draw_line(head, tail, color, 3.0, true)
		draw_circle(head, HEAD_RADIUS + 1.5, OUTLINE_COLOR)
		draw_circle(head, HEAD_RADIUS, color)
		draw_circle(tail, TAIL_RADIUS + 1.5, OUTLINE_COLOR)
		draw_circle(tail, TAIL_RADIUS, color)
		if show_names and bone_index < names.size():
			var label_position: Vector2 = head.lerp(tail, 0.5) + Vector2(6.0, -5.0)
			draw_string(
				ThemeDB.fallback_font,
				label_position,
				names[bone_index],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				11,
				Color(0.96, 0.97, 1.0, 0.95)
			)
