@tool
class_name GatorSpriteAnimation
extends Resource

@export var animation_title: String = "default"
@export_range(1.0, 120.0, 1.0) var frames_per_second: float = 12.0
@export var loop_mode: Animation.LoopMode = Animation.LOOP_LINEAR
@export var frame_count: int = 1
