extends Area2D

@export var fall_speed: float = 80.0
@export var move_to_slot_speed: float = 200.0

# Sway properties
@export var sway_amplitude: float = 12.0  # Width of the sway in pixels
@export var sway_frequency: float = 3.0   # Speed of the sway oscillation

var spawn_x: float = 0.0
var time_elapsed: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

enum State { FALLING, SQUISHED, JACKOLANTERN }
var current_state: State = State.FALLING

var target_position: Vector2 = Vector2.ZERO
var is_placed: bool = false
var ground_y: float = 195.0 # Match your 320x180 ground level

func _ready() -> void:
	sprite.play("falling")
	spawn_x = position.x
	# Offset time slightly so multiple pumpkins don't sway in perfect synchronization
	time_elapsed = randf_range(0.0, 10.0)

func _process(delta: float) -> void:
	match current_state:
		State.FALLING:
			# Vertical falling
			position.y += fall_speed * delta
			
			# Horizontal sine-wave sway
			time_elapsed += delta
			position.x = spawn_x + sin(time_elapsed * sway_frequency) * sway_amplitude
			
			# Squish when hitting the ground
			if position.y >= ground_y:
				squish_on_ground()
				
		State.SQUISHED, State.JACKOLANTERN:
			# Smoothly slide to slot position assigned by Main
			if not is_placed and target_position != Vector2.ZERO:
				position = position.move_toward(target_position, move_to_slot_speed * delta)
				if position == target_position:
					is_placed = true

func play_clean_sound(player_node: Node) -> void:
	if player_node != null and "stream" in player_node and player_node.stream != null:
		player_node.volume_db = -80.0
		player_node.play()
		
		var tween = create_tween()
		tween.tween_property(player_node, "volume_db", 3.0, 0.01)

func squish_on_ground() -> void:
	if current_state != State.FALLING:
		return
		
	current_state = State.SQUISHED
	sprite.play("squished")
	
	if has_node("SquishPlayer"):
		play_clean_sound($SquishPlayer)
	
	# Disable collision box once on ground
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Register with Main to get stack target position
	var main = get_parent()
	if main and main.has_method("register_squished_pumpkin"):
		main.register_squished_pumpkin(self)

func convert_to_jackolantern() -> void:
	if current_state != State.FALLING:
		return
		
	current_state = State.JACKOLANTERN
	sprite.play("jackolantern")
	
	if has_node("CacklePlayer"):
		play_clean_sound($CacklePlayer)
	
	# Disable collision box
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Register with Main to get sky stack target position
	var main = get_parent()
	if main and main.has_method("register_jackolantern"):
		main.register_jackolantern(self)
