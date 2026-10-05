extends Node3D

var a = 0

@export var NextScene : PackedScene 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("旋转"):
		a = 1
	else:
		a = 0
	
	var CHILDS = $Map.get_children()
	for body in CHILDS:
		if "Prat" in body.name:
			body.偏转度 += a
	
	pass

func To_Next_Level(body: Node3D) -> void:
	get_tree().change_scene_to_packed(NextScene)
	pass # Replace with function body.
