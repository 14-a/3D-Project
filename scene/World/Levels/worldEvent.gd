extends Node3D

@export var NextScene : PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func 旋转() -> void:
	改变()
	pass # Replace with function body.


func 改变() -> void:
	var Level_Part = $Map.get_children()
	
	for body in Level_Part:
		if "Prat" in body.name:
			body.偏转度 += 1
	pass


func toNextScene(body: Node3D) -> void:
	get_tree().change_scene_to_packed(NextScene)
	pass # Replace with function body.
