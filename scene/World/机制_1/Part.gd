extends Node3D

@export var 偏转度 = 0

@export var 反向 : bool

## -1是不启用这一项功能，意思是无论这个模块的方向如何都能通过
@export var 特定方向通过 = -1

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
