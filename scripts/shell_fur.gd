@tool
extends Node3D

enum SpawnMode { FUR, GRASS }
enum GrassDistribution { VERTICES, FACES, UNIFORM_GRID }

@export_group("General Settings")
@export var mode: SpawnMode = SpawnMode.FUR:
	set(value):
		mode = value
		notify_property_list_changed()
		update_fur()

@export var target_mesh_instance: MeshInstance3D:
	set(value):
		target_mesh_instance = value
		update_fur()

@export var regenerate: bool = false:
	set(value):
		update_fur()

@export_group("Fur Settings", "fur_")
@export var fur_base_mesh: Mesh
@export var fur_shell_count: int = 32
@export var fur_shell_height: float = 0.2

@export_group("Grass Settings", "grass_")
@export var grass_blade_mesh: Mesh
@export var grass_distribution: GrassDistribution = GrassDistribution.UNIFORM_GRID
@export var grass_density: float = 1.0:
	set(value):
		grass_density = value
		update_fur()
@export var grass_height_range: Vector2 = Vector2(0.5, 1.5)
@export var grass_height_noise_frequency: float = 0.5
@export var grass_rotation_range: float = 180.0
@export var grass_scale_range: Vector2 = Vector2(0.8, 1.2)
@export var grass_shell_count: int = 100  # Added shell count for grass

var material: ShaderMaterial
var multimesh_instance: MultiMeshInstance3D
var noise = FastNoiseLite.new()

func _ready():
	if not material:
		setup_material()
	noise.seed = randi()
	noise.frequency = 0.01
	update_fur()  # Ensure to call this

func _process(delta):
	if Engine.is_editor_hint() and regenerate:
		print("Updating grass/fur...")
		update_fur()
		regenerate = false


func setup_material():
	material = ShaderMaterial.new()
	var shader = load("res://shaders/shell_fur.gdshader") # Make sure shader is saved with this name
	material.shader = shader
	
	# Set default noise texture if none exists
	if not material.get_shader_parameter("noise_texture"):
		var noise_tex = NoiseTexture2D.new()
		noise_tex.noise = FastNoiseLite.new()
		noise_tex.noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise_tex.noise.frequency = 0.1
		material.set_shader_parameter("noise_texture", noise_tex)

func generate_grass_transforms(mesh: Mesh) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var vertices = []
	var normals = []
	
	# Get mesh data
	var arrays = mesh.surface_get_arrays(0)
	vertices = arrays[Mesh.ARRAY_VERTEX]
	normals = arrays[Mesh.ARRAY_NORMAL]
	
	match grass_distribution:
		GrassDistribution.VERTICES:
			for i in range(vertices.size()):
				if randf() > grass_density:
					continue
				var pos = vertices[i]
				var normal = normals[i]
				transforms.append(create_grass_transform(pos, normal))
				
		GrassDistribution.FACES:
			var indices = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				if randf() > grass_density:
					continue
				var face_center = (vertices[indices[i]] + vertices[indices[i+1]] + vertices[indices[i+2]]) / 3.0
				var face_normal = (normals[indices[i]] + normals[indices[i+1]] + normals[indices[i+2]]) / 3.0
				transforms.append(create_grass_transform(face_center, face_normal))
				
		GrassDistribution.UNIFORM_GRID:
			var indices = arrays[Mesh.ARRAY_INDEX]
			var aabb = mesh.get_aabb()
			var size = aabb.size
			var grid_density = int(grass_density * 50) # Control grid density by grass_density
			for x in range(grid_density):
				for z in range(grid_density):
					var pos_x = aabb.position.x + size.x * (float(x) / grid_density)
					var pos_z = aabb.position.z + size.z * (float(z) / grid_density)
					var ray_pos = Vector3(pos_x, aabb.position.y + size.y + 1.0, pos_z)
					var hit_pos = ray_pos
					hit_pos.y = get_height_at_point(vertices, indices, Vector2(pos_x, pos_z))
					if hit_pos.y != ray_pos.y:
						transforms.append(create_grass_transform(hit_pos, Vector3.UP))
	
	return transforms

func get_height_at_point(vertices: Array, indices: Array, point: Vector2) -> float:
	var closest_y = -1000.0
	for i in range(0, indices.size(), 3):
		var v1 = vertices[indices[i]]
		var v2 = vertices[indices[i+1]]
		var v3 = vertices[indices[i+2]]
		if point_in_triangle(point, Vector2(v1.x, v1.z), Vector2(v2.x, v2.z), Vector2(v3.x, v3.z)):
			var y = interpolate_height(point, v1, v2, v3)
			closest_y = max(closest_y, y)
	return closest_y

func point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 = signn(p - a, b - a)
	var d2 = signn(p - b, c - b)
	var d3 = signn(p - c, a - c)
	var has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

func signn(p1: Vector2, p2: Vector2) -> float:
	return (p1.x - p2.x) * (p1.y + p2.y)

func interpolate_height(p: Vector2, v1: Vector3, v2: Vector3, v3: Vector3) -> float:
	var total_area = triangle_area(Vector2(v1.x, v1.z), Vector2(v2.x, v2.z), Vector2(v3.x, v3.z))
	var w1 = triangle_area(p, Vector2(v2.x, v2.z), Vector2(v3.x, v3.z)) / total_area
	var w2 = triangle_area(p, Vector2(v3.x, v3.z), Vector2(v1.x, v1.z)) / total_area
	var w3 = 1.0 - w1 - w2
	return v1.y * w1 + v2.y * w2 + v3.y * w3

func triangle_area(a: Vector2, b: Vector2, c: Vector2) -> float:
	return abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2.0

func create_grass_transform(position: Vector3, normal: Vector3) -> Transform3D:
	var transform = Transform3D()
	
	# Random rotation around normal
	var angle = randf_range(0, deg_to_rad(grass_rotation_range))
	var rot_basis = Basis(normal, angle)
	
	# Align with normal
	var up = Vector3.UP
	if normal != up:
		var axis = up.cross(normal).normalized()
		var angle_to_normal = up.angle_to(normal)
		rot_basis = rot_basis.rotated(axis, angle_to_normal)
	
	# Random scale
	var scale = randf_range(grass_scale_range.x, grass_scale_range.y)
	var height = randf_range(grass_height_range.x, grass_height_range.y)
	height *= 1.0 + noise.get_noise_2d(position.x * grass_height_noise_frequency, 
									 position.z * grass_height_noise_frequency)
	
	transform.basis = rot_basis
	transform.basis = transform.basis.scaled(Vector3(scale, height, scale))
	transform.origin = position
	
	return transform

func update_fur():
	if not is_node_ready():
		return
		
	if not target_mesh_instance or not target_mesh_instance.mesh:
		push_warning("Please assign a MeshInstance3D with a valid mesh as the target.")
		return
		
	if mode == SpawnMode.FUR and not fur_base_mesh:
		push_warning("Please assign a base mesh for fur mode")
		return
		
	if mode == SpawnMode.GRASS and not grass_blade_mesh:
		push_warning("Please assign a grass blade mesh")
		return

	# Remove old instance if it exists
	if multimesh_instance:
		remove_child(multimesh_instance)
		multimesh_instance.queue_free()

	if not material:
		setup_material()

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	
	if mode == SpawnMode.FUR:
		multimesh.instance_count = fur_shell_count
		multimesh.mesh = fur_base_mesh
		
		for i in range(fur_shell_count):
			var transform = Transform3D()
			transform.basis = Basis()
			transform.origin = get_random_point_on_mesh(target_mesh_instance)
			transform.origin.y += fur_shell_height * i  # Offset by height for each shell
			multimesh.set_instance_transform(i, transform)
	elif mode == SpawnMode.GRASS:
	# Ensure you are generating the number of grass blades defined by grass_shell_count
		var transforms = []
		for i in range(grass_shell_count):
			var transform = Transform3D()
			transform.basis = Basis()  # Default rotation
			transform.origin = get_random_point_on_mesh(target_mesh_instance)  # Get a random position on the mesh
			transforms.append(transform)
		
		multimesh.instance_count = transforms.size()
		multimesh.mesh = grass_blade_mesh
		
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])

	var transforms = []
	for i in range(grass_shell_count):
		var transform = Transform3D()
		transform.basis = Basis()  # Default rotation
		transform.origin = get_random_point_on_mesh(target_mesh_instance)  # Get a random position on the mesh
		transforms.append(transform)
	
	multimesh.instance_count = transforms.size()
	multimesh.mesh = grass_blade_mesh
	
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = multimesh
	multimesh_instance.material_override = material
	add_child(multimesh_instance)

func get_random_point_on_mesh(mesh_instance: MeshInstance3D) -> Vector3:
	var mesh = mesh_instance.mesh
	var aabb = mesh.get_aabb()
	var random_point = Vector3(
		randf_range(aabb.position.x, aabb.position.x + aabb.size.x),
		randf_range(aabb.position.y, aabb.position.y + aabb.size.y),
		randf_range(aabb.position.z, aabb.position.z + aabb.size.z)
	)
	return random_point
