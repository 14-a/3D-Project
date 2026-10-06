extends Node3D

var _按钮按下 : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _按钮按下:
		$%button.position.y += (-0.1 - $%button.position.y) * delta * 10
	else:
		$%button.position.y += (0 - $%button.position.y) * delta * 10
	pass


func 按钮按下(body: Node3D) -> void:
	_按钮按下 = true
	print("大按钮", self.name, "按下")
	pass # Replace with function body.

func 玩家离开(body: Node3D) -> void:
	_按钮按下 = false
	print("大按钮", self.name, "松开")
	pass # Replace with function body.
