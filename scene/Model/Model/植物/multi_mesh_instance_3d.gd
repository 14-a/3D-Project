@tool
extends MultiMeshInstance3D

## 灌木丛底部半径
@export var bush_radius := 1.0
## 灌木丛高度
@export var bush_height := 1.5
## 叶片数量（越多越密）
@export var leaf_count := 200
## 每片叶子的基础网格（若为空，自动使用一个小立方体）
@export var leaf_mesh : Mesh
## 叶片材质（若为空，自动使用绿色材质）
@export var leaf_material : Material
## 随机种子，相同种子产生相同灌木丛
@export var random_seed := 0


func _ready() -> void:
	generate_bush()


func generate_bush() -> void:
	# 准备叶片网格和材质
	if leaf_mesh == null:
		var box = BoxMesh.new()
		box.size = Vector3(0.1, 0.1, 0.1)
		leaf_mesh = box

	if leaf_material == null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.8, 0.2)
		leaf_material = mat

	# 创建 MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true          # 启用逐实例颜色
	multimesh.mesh = leaf_mesh
	multimesh.instance_count = leaf_count

	# 设置随机种子
	seed(random_seed)

	# 生成每一个叶片实例
	for i in range(leaf_count):
		# 在扁椭球内生成位置（底部宽，顶部略窄）
		var pos = _random_point_in_bush()

		# 随机缩放
		var scale = Vector3.ONE * randf_range(0.2, 0.7)

		# 随机旋转，让叶片朝向不同方向
		var angle_y = randf_range(0.0, TAU)
		var tilt_x = randf_range(-0.5, 0.5)
		var tilt_z = randf_range(-0.5, 0.5)
		var basis = Basis.from_euler(Vector3(tilt_x, angle_y, tilt_z))

		var transform = Transform3D(basis, pos)
		# 应用缩放（basis 会被缩放影响，所以放在构造里或单独乘）
		transform = transform.scaled(scale)

		multimesh.set_instance_transform(i, transform)

		# 随机绿色调
		var green = Color(
			randf_range(0.1, 0.35),
			randf_range(0.5, 0.9),
			randf_range(0.1, 0.3)
		)
		multimesh.set_instance_color(i, green)

	self.multimesh = multimesh


# 在灌木丛的体积内生成随机点
func _random_point_in_bush() -> Vector3:
	# y 从 0 到 bush_height
	var y = randf_range(0.0, bush_height)
	# 高度越高，半径略微缩小，形成上窄下宽的形状
	var radius_at_y = bush_radius * (1.0 - y / bush_height * 0.4)
	# 圆盘内均匀分布
	var angle = randf_range(0.0, TAU)
	var dist = sqrt(randf()) * radius_at_y   # sqrt 保证面积均匀
	var x = cos(angle) * dist
	var z = sin(angle) * dist
	return Vector3(x, y, z)
