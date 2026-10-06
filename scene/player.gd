extends CharacterBody3D

@onready var 镜头轴承 = $Node3D
@onready var ViewRay = $RayCast3D

@export var 鼠标灵敏度 = 0.1

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const 虚空高度 = -10

var speed = 1

func _ready() -> void:
	ViewRay.target_position = Vector3(0,0,-10)
	ViewRay.add_exception($CollisionShape3D)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * 鼠标灵敏度
		镜头轴承.rotation_degrees.x -= event.relative.y * 鼠标灵敏度
		if 镜头轴承.rotation_degrees.x > 89: 镜头轴承.rotation_degrees.x = 89
		if 镜头轴承.rotation_degrees.x < -89: 镜头轴承.rotation_degrees.x = -89
		ViewRay.rotation_degrees.x = 镜头轴承.rotation_degrees.x
		pass
		
	if Input.is_action_just_pressed("退出"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else : 
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor(): velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("跳") and is_on_floor():velocity.y = JUMP_VELOCITY

	if Input.is_action_pressed("疾跑"):
		speed = 1.5
		$Node3D/Camera3D.fov += (100 - $Node3D/Camera3D.fov) * .1
	else :
		speed = 1
		$Node3D/Camera3D.fov += (90 - $Node3D/Camera3D.fov) * .1
	
	if Input.is_action_pressed("聚焦"): $Node3D/Camera3D.fov += (20 - $Node3D/Camera3D.fov) * .1
	
	if Input.is_action_pressed("蹲下"):
		$Node3D.position.y += (1 - $Node3D.position.y) * .1
		$RayCast3D.position.y += (1 - $RayCast3D.position.y) * .1
		$MeshInstance3D.scale.y += (0.5 - $MeshInstance3D.scale.y) * .1
		$CollisionShape3D.scale.y += (0.5 - $CollisionShape3D.scale.y) * .1
	else : 
		$Node3D.position.y += (1.694 - $Node3D.position.y) * .1
		$RayCast3D.position.y += (1.694 - $RayCast3D.position.y) * .1
		$MeshInstance3D.scale.y += (1 - $MeshInstance3D.scale.y) * .1
		$CollisionShape3D.scale.y += (1 - $CollisionShape3D.scale.y) * .1
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("左", "右", "前", "后")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED * speed
		velocity.z = direction.z * SPEED * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * speed)
		velocity.z = move_toward(velocity.z, 0, SPEED * speed)

	move_and_slide()
	
	_Player_Event()


func _Player_Event() -> void: 
	if Input.is_action_pressed("交互"):pass  
	
	if position.y < 虚空高度:
		position = Vector3(0,2,0)
	pass
