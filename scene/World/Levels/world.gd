extends Node3D

@export var Chapter : Array[PackedScene]

var Levels

var LevelIndex = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Levels = Chapter[LevelIndex].instantiate()
	add_child(Levels)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Levels.Next:
		
		
		$Player.position = Vector3(0,1,0)
		Levels.queue_free()
		LevelIndex += 1
		Levels = Chapter[LevelIndex].instantiate()
		add_child(Levels)
	
	pass
