extends Area2D

@export var fly_speed: float = 120.0

@onready var sprite: Sprite2D = $Sprite2D

var screen_width: float = 320.0
var max_y: float = 135.0 # Top 75% of 180px viewport height

# Off-screen boundaries
var start_x_right: float = 360.0
var end_x_left: float = -130.0

enum ScaleMode { GROW, SHRINK }
var current_scale_mode: ScaleMode = ScaleMode.SHRINK

enum State { FLY_LEFT, PAUSING, FLY_RIGHT, FINISHED }
var current_state: State = State.FLY_LEFT

func _ready() -> void:
	z_index = 1 # Behind pumpkins/player, in front of background
	
	# Decide initial scale behavior (50% chance to grow, 50% chance to shrink)
	current_scale_mode = ScaleMode.GROW if randf() > 0.5 else ScaleMode.SHRINK
	
	# Start off-screen to the right, facing Left
	position = Vector2(start_x_right, randf_range(15.0, max_y))
	if sprite:
		sprite.flip_h = false # Base sprite faces left

func _process(delta: float) -> void:
	match current_state:
		State.FLY_LEFT:
			position.x -= fly_speed * delta
			update_flight_scale(position.x, start_x_right, end_x_left)
			
			# Fully cross past the left edge
			if position.x < end_x_left:
				prepare_return_flight()

		State.FLY_RIGHT:
			position.x += fly_speed * delta
			update_flight_scale(position.x, end_x_left, start_x_right)
			
			# Fully cross past the right edge
			if position.x > start_x_right:
				current_state = State.FINISHED
				queue_free()

func update_flight_scale(current_x: float, from_x: float, to_x: float) -> void:
	# Progress ratio from 0.0 (start of flight) to 1.0 (end of flight)
	var t: float = remap(current_x, from_x, to_x, 0.0, 1.0)
	t = clamp(t, 0.0, 1.0)
	
	var current_scale: float = 1.0
	if current_scale_mode == ScaleMode.SHRINK:
		current_scale = lerp(2.0, 0.25, t) # 100% down to 50%
	else:
		current_scale = lerp(0.25, 2.0, t) # 50% up to 100%
		
	scale = Vector2(current_scale, current_scale)

func prepare_return_flight() -> void:
	current_state = State.PAUSING
	
	# Brief pause off-screen left
	await get_tree().create_timer(randf_range(0.3, 1.0)).timeout
	
	if not is_inside_tree():
		return
		
	# New random height in top 75%
	position.y = randf_range(15.0, max_y)
	
	# Randomize scale behavior for the return trip
	current_scale_mode = ScaleMode.GROW if randf() > 0.5 else ScaleMode.SHRINK
	
	# Flip sprite horizontally to face Right
	if sprite:
		sprite.flip_h = true
		
	current_state = State.FLY_RIGHT
