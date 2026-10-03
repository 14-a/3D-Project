
extends Node3D

@export var Player : CharacterBody3D

## 旋转速度
@export var orbit_speed: float = 0.005

## 最小俯仰角（度）
@export var min_pitch: float = -80.0

## 最大俯仰角（度）
@export var max_pitch: float = 10.0

@export var _elevation: float = -53.9

var _azimuth: float = 0.0
var _is_dragging: bool = false

func _input(event: InputEvent) -> void:
	# 监听鼠标左键按下/释放事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed

	# 当按住左键并拖动鼠标时
	if event is InputEventMouseMotion and _is_dragging:
		_azimuth -= event.relative.x * orbit_speed
		_elevation -= event.relative.y * orbit_speed * 50
		_elevation = clamp(_elevation, min_pitch, max_pitch)
		update_camera_rotation()

func update_camera_rotation() -> void:
	# 重置旋转，然后应用新的角度
	rotation = Vector3.ZERO
	rotate_object_local(Vector3.UP, _azimuth)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(_elevation))
	if Player:
		var v = Vector3(round(transform.basis.z.x),0,round(transform.basis.z.z)).normalized()
		Player.z = v
		var v_1 = Vector3(round(transform.basis.x.x),0,round(transform.basis.x.z)).normalized()
		Player.x = v_1
