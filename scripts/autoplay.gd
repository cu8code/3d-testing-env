extends Node3D

@export var animation_name: String
@export var target: AnimationPlayer
@export_group("Animation Settings")
@export var play_speed: float = 1.0
@export var random_start_point: bool = false
@export var loop_animation: bool = true
@export var reverse_on_loop: bool = false
@export_range(0.0, 1.0) var random_start_min: float = 0.0
@export_range(0.0, 1.0) var random_start_max: float = 1.0

# Advanced settings
@export_group("Advanced Settings")
@export var play_on_ready: bool = true
@export var random_speed_variation: bool = false
@export_range(0.0, 2.0) var speed_variation_range: float = 0.2

var playing_forward: bool = true
var initial_start: bool = true

func _ready():
	if not target:
		push_warning("No AnimationPlayer assigned to " + name)
		return
		
	if play_on_ready:
		start_animation()

func start_animation():
	if not target:
		return
		
	# Set animation speed
	var final_speed = play_speed
	if random_speed_variation:
		final_speed += randf_range(-speed_variation_range, speed_variation_range)
	target.speed_scale = final_speed
	
	# Set random start point if enabled
	if random_start_point and initial_start:
		var random_position = randf_range(random_start_min, random_start_max)
		var anim_length = target.get_animation(animation_name).length
		target.seek(random_position * anim_length, true)
	
	target.play(animation_name)
	target.animation_finished.connect(_on_animation_finished)
	initial_start = false

func stop_animation():
	if target:
		target.stop()
		if target.animation_finished.is_connected(_on_animation_finished):
			target.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(_anim_name):
	if not loop_animation:
		return
		
	if reverse_on_loop:
		playing_forward = !playing_forward
		target.speed_scale = play_speed * (-1 if !playing_forward else 1)
		
	if random_speed_variation:
		var final_speed = play_speed
		final_speed += randf_range(-speed_variation_range, speed_variation_range)
		target.speed_scale = final_speed * (-1 if !playing_forward else 1)
		
	target.play(animation_name)

# Public methods for external control
func set_speed(new_speed: float):
	play_speed = new_speed
	if target:
		target.speed_scale = new_speed * (-1 if !playing_forward else 1)

func toggle_pause():
	if target:
		target.paused = !target.paused

func reset_animation():
	if target:
		target.seek(0, true)
		playing_forward = true
		target.speed_scale = play_speed
