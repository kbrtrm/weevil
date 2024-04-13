extends AudioStreamPlayer

# Define an array of audio samples
var audio_samples = [
	preload("res://Music and Sounds/moss-rustle.wav")
]

@onready var pitch_variance = 0.25

# Function to play a random sample with a randomized pitch
func play_random_moss_sample():
	# Select a random audio sample from the array
	var random_index = randi() % audio_samples.size()
	stream = audio_samples[random_index]

	# Generate a random pitch offset within the specified range
	var random_pitch = randf_range(-pitch_variance, pitch_variance)

	# Apply the pitch offset
	pitch_scale = 1.0 + random_pitch
	volume_db = -50.0

	# Play the audio sample
	play()
