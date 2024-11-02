extends CharacterBody3D

const SPEED = 2.0
const JUMP_VELOCITY = 4.5
@onready var player := $Walking/AnimationPlayer
@onready var rotate_point := $Walking

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Check if there's movement input and apply velocity accordingly.
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		# Rotate the character to face the movement direction.
		rotate_point.rotation.y = deg_to_rad(0) + atan2(-direction.x, direction.z)
		
		# Play the walking animation if it's not already playing.
		if is_on_floor() and !player.is_playing():
			player.play("mixamo_com")
	else:
		# Gradually stop the character if no input.
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
		# Stop the animation if there's no movement and on the floor.
		if is_on_floor() and player.is_playing():
			player.stop()
	
	move_and_slide()
