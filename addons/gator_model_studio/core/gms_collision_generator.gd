@tool
class_name GMSCollisionGenerator
extends RefCounted





static func create_static_body(
	object: GMSModelObject,
	evaluated_mesh: GMSMeshData
) -> StaticBody3D:
	if object == null or evaluated_mesh == null:
		return null
	if object.collision_type == GMSModelObject.CollisionType.NONE:
		return null
	var generated: Dictionary = create_shape(evaluated_mesh, object.collision_type)
	var shape: Shape3D = generated.get("shape") as Shape3D
	if shape == null:
		return null

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1 << (clampi(object.collision_layer, 1, 32) - 1)
	body.collision_mask = 1 << (clampi(object.collision_mask, 1, 32) - 1)
	body.set_meta("gms_generated_collision", true)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.transform = generated.get("transform", Transform3D.IDENTITY)
	body.add_child(collision_shape)
	return body


static func create_shape(mesh_data: GMSMeshData, collision_type: int) -> Dictionary:
	var result: Dictionary = {"shape": null, "transform": Transform3D.IDENTITY}
	if mesh_data == null or not mesh_data.is_valid() or mesh_data.faces.is_empty():
		return result
	var bounds: AABB = mesh_data.get_aabb()
	var size: Vector3 = bounds.size.abs()
	var center: Vector3 = bounds.get_center()
	var local_transform: Transform3D = Transform3D.IDENTITY
	local_transform.origin = center

	match collision_type:
		GMSModelObject.CollisionType.TRIMESH:
			var triangle_mesh: ArrayMesh = mesh_data.to_array_mesh([], false)
			result["shape"] = triangle_mesh.create_trimesh_shape()
		GMSModelObject.CollisionType.CONVEX:
			var convex_mesh: ArrayMesh = mesh_data.to_array_mesh([], false)
			result["shape"] = convex_mesh.create_convex_shape(true, false)
		GMSModelObject.CollisionType.BOX:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(
				maxf(size.x, 0.001),
				maxf(size.y, 0.001),
				maxf(size.z, 0.001)
			)
			result["shape"] = box
			result["transform"] = local_transform
		GMSModelObject.CollisionType.SPHERE:
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = maxf(maxf(size.x, size.y), size.z) * 0.5
			sphere.radius = maxf(sphere.radius, 0.0005)
			result["shape"] = sphere
			result["transform"] = local_transform
		GMSModelObject.CollisionType.CAPSULE:
			var capsule: CapsuleShape3D = CapsuleShape3D.new()
			capsule.radius = maxf(maxf(size.x, size.z) * 0.5, 0.0005)
			capsule.height = maxf(size.y, capsule.radius * 2.0)
			result["shape"] = capsule
			result["transform"] = local_transform
	return result
