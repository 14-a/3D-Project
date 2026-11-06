extends Node3D

@export var Chapter : Array[PackedScene]

var Levels

var LevelIndex = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Levels = Chapter[LevelIndex].instantiate()
	add_child(Levels)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Levels.Next:
		var fade_layer = ColorRect.new()
		fade_layer.color = Color(0, 0, 0, 0)   # 初始透明
		var tween = create_tween()
		
		fade_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_tree().root.add_child(fade_layer)
		tween.tween_property(fade_layer, "color:a", 1.0, 0.5)
		
		LevelIndex += 1
			
		$Player.position = Vector3(0,1,0)
		Levels.queue_free()
		Levels = Chapter[LevelIndex].instantiate()
		add_child(Levels)
	
		tween.tween_property(fade_layer, "color:a", 0.0, 0.5)
		tween.tween_callback(fade_layer.queue_free)
	pass
