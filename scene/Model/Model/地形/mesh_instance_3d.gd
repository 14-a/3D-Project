@tool
extends MeshInstance3D

# 地形参数
@export var width: int = 100          # X轴顶点数
@export var depth: int = 100          # Z轴顶点数
@export var spacing: float = 1.0      # 顶点间距
@export var height_scale: float = 10.0 # 高度缩放

# 噪声参数
@export var noise_seed: int = 0
@export var noise_frequency: float = 0.03
@export var noise_octaves: int = 4
@export var noise_lacunarity: float = 2.0
@export var noise_gain: float = 0.5

# 是否生成碰撞
@export var generate_collision: bool = true

var noise: FastNoiseLite

func _ready():
	generate_terrain()

func generate_terrain():
	# 初始化噪声
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN  # 可换成 SIMPLEX 等
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_gain

	# 构建网格
	var mesh = ArrayMesh.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 生成顶点数据
	for z in range(depth):
		for x in range(width):
			var px = x * spacing
			var pz = z * spacing
			var py = noise.get_noise_2d(px, pz) * height_scale
			surface_tool.set_uv(Vector2(px / width, pz / depth))
			surface_tool.add_vertex(Vector3(px, py, pz))

	# 生成索引（两个三角形组成一个网格单元）
	for z in range(depth - 1):
		for x in range(width - 1):
			var i = z * width + x
			# 第一个三角形
			surface_tool.add_index(i + 1)
			surface_tool.add_index(i + width)
			surface_tool.add_index(i)
			# 第二个三角形
			surface_tool.add_index(i + width + 1)
			surface_tool.add_index(i + width)
			surface_tool.add_index(i + 1)

	# 生成法线并提交网格
	surface_tool.generate_normals()
	surface_tool.commit(mesh)
	self.mesh = mesh

	# 生成碰撞体
	if generate_collision:
		create_collision()

func create_collision():
	# 移除已有碰撞体（避免重复生成）
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()

	var static_body = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	add_child(static_body)

	var collision_shape = CollisionShape3D.new()
	# 使用凹形碰撞形状（ConcavePolygonShape3D）以支持复杂地形
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(self.mesh.get_faces())  # 从网格面生成碰撞数据
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
