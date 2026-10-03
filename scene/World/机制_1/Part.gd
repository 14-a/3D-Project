extends Node3D

@export var 偏转度 = 0

@export var 反向 : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if 反向:
		rotation_degrees.y += (偏转度 * 90 - rotation_degrees.y) * delta * 2
	else :
		rotation_degrees.y += (偏转度 * -90 - rotation_degrees.y) * delta * 2
	
	pass
