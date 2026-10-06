extends Node3D

var 可交互 : bool

var 动画 : bool

signal 小按钮触发

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	var InAreasModel = $%Area3D.get_overlapping_bodies()
	
	可交互 = false
	
	for body in InAreasModel:
		if body.name == "Player":
			可交互 = true
	
	if 可交互:
		if Input.is_action_just_pressed("交互"):
			动画 = true
			$%Cylinder_02.position.y -= 0.05
			print("小按钮:",self,"点击")
			小按钮触发.emit()
	
	if 动画:
		if abs($%Cylinder_02.position.y - 1.068) < 0.001:
			动画 = false
		
		$%Cylinder_02.position.y += (1.068 - $%Cylinder_02.position.y) * delta * 10
		pass
	
	pass
