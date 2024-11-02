extends Node3D

# Export variables for inspector configuration
@export_group("Tracking Settings")
@export var target: Node3D
@export var rotation_smoothing: float = 0.1
@export var enable_full_3d_tracking: bool = true
@export var initial_rotation_offset_deg: Vector3 = Vector3.ZERO  # Degrees
@export var up_direction: Vector3 = Vector3.UP

@export_group("Scaling Animation")
@export var enable_breathing: bool = true
@export var breathing_min_scale: float = 0.95
@export var breathing_max_scale: float = 1.05
@export var breathing_speed: float = 1.5

@export_group("Idle Animation")
@export var enable_idle_movement: bool = true
@export var idle_trigger_time: float = 3.0
@export var idle_movement_speed: float = 2.0
@export var idle_movement_range: float = 0.1

# Private variables
var initial_transform: Transform3D
var idle_time: float = 0.0
var breathing_time: float = 0.0
var last_target_pos: Vector3 = Vector3.ZERO
var is_idle: bool = false
var current_idle_offset: Vector3 = Vector3.ZERO

func _ready():
	# Store initial transform and apply offset in radians
	initial_transform = transform
	global_rotation += Vector3(deg_to_rad(initial_rotation_offset_deg.x),
						deg_to_rad(initial_rotation_offset_deg.y),
						deg_to_rad(initial_rotation_offset_deg.z))
	
	if target:
		last_target_pos = target.global_position

func _process(delta: float):
	if not target:
		return
	
	update_idle_state(delta)
	handle_tracking(delta)
	handle_breathing(delta)

func update_idle_state(delta: float):
	var target_moved = target.global_position.distance_to(last_target_pos) > 0.01
	last_target_pos = target.global_position
	
	if target_moved:
		idle_time = 0.0
		is_idle = false
	else:
		idle_time += delta
		if idle_time >= idle_trigger_time:
			is_idle = true

func handle_tracking(delta: float):
	var direction = (target.global_position - global_position).normalized()
	var target_transform := Transform3D()
	
	if direction.length() > 0.001:
		target_transform = target_transform.looking_at(direction, up_direction)
		
		# Apply initial rotation offset to target transform
		target_transform.basis = target_transform.basis.rotated(Vector3.RIGHT, deg_to_rad(initial_rotation_offset_deg.x))
		target_transform.basis = target_transform.basis.rotated(Vector3.UP, deg_to_rad(initial_rotation_offset_deg.y))
		target_transform.basis = target_transform.basis.rotated(Vector3.FORWARD, deg_to_rad(initial_rotation_offset_deg.z))
	
	if is_idle and enable_idle_movement:
		current_idle_offset = calculate_idle_offset()
		target_transform.basis = target_transform.basis.rotated(Vector3.RIGHT, current_idle_offset.x)
		target_transform.basis = target_transform.basis.rotated(Vector3.UP, current_idle_offset.y)
	
	if enable_full_3d_tracking:
		global_transform = global_transform.interpolate_with(
			Transform3D(target_transform.basis, global_position),
			rotation_smoothing
		)
	else:
		var current_rot = global_rotation
		var target_rot = target_transform.basis.get_euler()
		current_rot.y = lerp_angle(current_rot.y, target_rot.y, rotation_smoothing)
		global_rotation = current_rot


func handle_breathing(delta: float):
	if enable_breathing:
		breathing_time += delta * breathing_speed
		var breathing_factor = lerp(
			breathing_min_scale,
			breathing_max_scale,
			(sin(breathing_time) + 1.0) * 0.5
		)
		scale = Vector3.ONE * breathing_factor

func calculate_idle_offset() -> Vector3:
	var idle_x = sin(idle_time * idle_movement_speed) * idle_movement_range
	var idle_y = cos(idle_time * idle_movement_speed * 0.7) * idle_movement_range
	return Vector3(idle_x, idle_y, 0.0)

func reset():
	transform = initial_transform
	rotation += Vector3(deg_to_rad(initial_rotation_offset_deg.x),
						deg_to_rad(initial_rotation_offset_deg.y),
						deg_to_rad(initial_rotation_offset_deg.z))
	idle_time = 0.0
	breathing_time = 0.0
	is_idle = false
	scale = Vector3.ONE

# Helper function for angle interpolation
func lerp_angle(from: float, to: float, weight: float) -> float:
	return from + short_angle_dist(from, to) * weight

# Helper function for finding shortest rotation path
func short_angle_dist(from: float, to: float) -> float:
	var max_angle = PI * 2
	var difference = fmod(to - from, max_angle)
	return fmod(2 * difference, max_angle) - difference
