extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_小按钮_小按钮触发() -> void:
	$Prat2.偏转度 += 1
	$Prat3.偏转度 += 1
	pass # Replace with function body.
