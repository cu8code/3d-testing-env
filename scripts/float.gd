extends Node3D

@export var amplitude_range : Vector2 = Vector2(0.3, 0.7)  # Min and max float height
@export var frequency_range : Vector2 = Vector2(0.8, 1.5)  # Min and max float speed
@export var time_offset_range : Vector2 = Vector2(0.0, 10.0)  # Random time offset range

var initial_position : Vector3
var time_passed : float = 0.0

# Randomized parameters for this specific instance
var float_amplitude : float
var float_frequency : float
var time_offset : float

func _ready() -> void:
	# Randomize the floating parameters
	randomize_float_parameters()
	
	# Store the initial position to float around
	initial_position = position

func randomize_float_parameters() -> void:
	# Randomize amplitude within the specified range
	float_amplitude = randf_range(amplitude_range.x, amplitude_range.y)
	
	# Randomize frequency within the specified range
	float_frequency = randf_range(frequency_range.x, frequency_range.y)
	
	# Randomize time offset to desynchronize floating
	time_offset = randf_range(time_offset_range.x, time_offset_range.y)

func _process(delta: float) -> void:
	# Increment time passed with random offset
	time_passed += delta
	
	# Calculate the vertical offset using a sine wave with randomized parameters
	var vertical_offset = sin((time_passed + time_offset) * float_frequency) * float_amplitude
	
	# Set the new position, maintaining original X and Z coordinates
	position = initial_position + Vector3(0, vertical_offset, 0)

# Optional: Randomize parameters periodically or on demand
func re_randomize() -> void:
	randomize_float_parameters()
