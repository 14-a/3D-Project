extends CharacterBody3D

enum 状态 {
	移动 = 0,
	过场_对话 = 1,
	过场切换场景 = 2,
	虚空 = -10
}

var Level_ReadyPosition = Vector3(0,1,0)
var ReadyPosition = Level_ReadyPosition

const 虚空 = -100
const SPEED = 10
const JUMP_VELOCITY = 4.5

var stated = 状态.移动

var z : Vector3 = Vector3(0,0,1)
var x : Vector3 = Vector3(1,0,0)

func _ready() -> void:
	position = ReadyPosition
	pass

func _physics_process(delta: float) -> void:
	
	if stated == 状态.移动:
		if not is_on_floor():
			velocity += get_gravity() * delta
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity += get_gravity().normalized() * -JUMP_VELOCITY
		
		var direction = Vector3.ZERO
	
		if Input.is_action_pressed("左"):
			direction -= x
		if Input.is_action_pressed("右"):
			direction += x
		if Input.is_action_pressed("后"):
			direction += z
		if Input.is_action_pressed("前"):
			direction -= z
		
		if direction != Vector3.ZERO:
			direction = direction.normalized()
			basis = Basis.looking_at(direction)
		
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		move_and_slide()

	Event(delta)
	
func Event(Delta) -> void:
	if position.y < 状态.虚空:
		position = ReadyPosition
	pass
