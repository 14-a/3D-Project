@tool
extends MeshInstance3D

@export var Order = 10:
	set(v):
		Order = v
		_Make()

@export var StepLength = 1.00:
	set(v):
		StepLength = v
		_Make()

@export var StepWidth = 1.00:
	set(v):
		StepWidth = v
		_Make()

@export var heightDifference = 0.20:
	set(v):
		heightDifference = v
		_Make()

@export var 更新 : bool = false :
	set(v):
		_Make()
		更新 = false

@export var generate_collision : bool = true : set = _on_collision_changed

@export var Materials : Material

var st = SurfaceTool.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_Make()
	pass # Replace with function body.

func _Make() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	st.set_smooth_group(-1)
	
	add_a(StepLength,StepWidth,heightDifference,Vector3(0,0,0))
	
	for i in range(Order - 2):
		add_c(StepLength,StepWidth,heightDifference * (i+2),Vector3(0,0,StepLength * (i + 1)), heightDifference)
		pass
	
	add_b(StepLength,StepWidth,heightDifference * Order,Vector3(0,0,StepLength * (Order - 1)))
	
	st.set_material(Materials)
	st.generate_normals()
	self.mesh = st.commit()
	_update_collision()
	
	pass

func _update_collision():
	if not generate_collision:
		_remove_collision()
		return

	var static_body = get_node_or_null("StaticBody3D")
	if not static_body:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		add_child(static_body)
		static_body.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	# 清除旧的碰撞体
	for child in static_body.get_children():
		child.queue_free()


	# 创建斜面形状
	var collision_shape = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new()
	
	var total_length = Order * StepLength
	var total_height = Order * heightDifference
	
	var v0 = Vector3(0, 0, 0)
	var v1 = Vector3(StepWidth, 0, 0)
	var v2 = Vector3(0, total_height, total_length)
	var v3 = Vector3(StepWidth, total_height, total_length)
	
	var faces = [
		v0, v1, v2,
		v3, v2, v1
	]
	shape.data = PackedVector3Array(faces)
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	collision_shape.owner = static_body.owner

func _remove_collision():
	var static_body = get_node_or_null("StaticBody3D")
	if static_body:
		static_body.queue_free()

func _on_collision_changed(value):
	generate_collision = value
	_update_collision()

func add_a(a,b,c,Pos : Vector3) -> void:
	add_face(
		Vector3( 0 ,c, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos ,
		Vector3( 0 ,c, a ) +Pos ,
		Vector3( b ,c, a ) +Pos
		)
	
	add_face(
		Vector3( b ,0, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos ,
		Vector3( 0 ,0, 0 ) +Pos ,
		Vector3( 0 ,c, 0 ) +Pos
		)
	
	add_face(
		Vector3( 0 ,0, 0 ) +Pos ,
		Vector3( 0 ,c, 0 ) +Pos ,
		Vector3( 0 ,0, a ) +Pos ,
		Vector3( 0 ,c, a ) +Pos
		)
	
	add_face(
		Vector3( b ,0, a ) +Pos ,
		Vector3( b ,c, a ) +Pos ,
		Vector3( b ,0, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos
		)
	pass

func add_b(a,b,c,Pos : Vector3) -> void:
	add_face(
		Vector3( 0 ,c, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos ,
		Vector3( 0 ,c, a ) +Pos ,
		Vector3( b ,c, a ) +Pos
		)
	
	add_face(
		Vector3( b ,0, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos ,
		Vector3( 0 ,0, 0 ) +Pos ,
		Vector3( 0 ,c, 0 ) +Pos
		)
	
	add_face(
		Vector3( 0 ,0, a ) +Pos ,
		Vector3( 0 ,c, a ) +Pos ,
		Vector3( b ,0, a ) +Pos ,
		Vector3( b ,c, a ) +Pos
		)
	
	add_face(
		Vector3( 0 ,0, 0 ) +Pos ,
		Vector3( 0 ,c, 0 ) +Pos ,
		Vector3( 0 ,0, a ) +Pos ,
		Vector3( 0 ,c, a ) +Pos
		)
	
	add_face(
		Vector3( b ,0, a ) +Pos ,
		Vector3( b ,c, a ) +Pos ,
		Vector3( b ,0, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos
		)
	pass

func add_c(a,b,c,Pos : Vector3, d) -> void:
	add_face(
		Vector3( 0 ,c, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos ,
		Vector3( 0 ,c, a ) +Pos ,
		Vector3( b ,c, a ) +Pos
		)
	
	add_face(
		Vector3( b ,c-d, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos ,
		Vector3( 0 ,c-d, 0 ) +Pos ,
		Vector3( 0 ,c, 0 ) +Pos
		)
	
	add_face(
		Vector3( 0 ,0, 0 ) +Pos ,
		Vector3( 0 ,c, 0 ) +Pos ,
		Vector3( 0 ,0, a ) +Pos ,
		Vector3( 0 ,c, a ) +Pos
		)
	
	add_face(
		Vector3( b ,0, a ) +Pos ,
		Vector3( b ,c, a ) +Pos ,
		Vector3( b ,0, 0 ) +Pos ,
		Vector3( b ,c, 0 ) +Pos
		)
	pass

func add_face(v1,v2,v3,v4) -> void:
	_add_face(v1,v2,v3)
	_add_face(v4,v3,v2)
	pass

func _add_face(v1,v2,v3) -> void:
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)
	pass
