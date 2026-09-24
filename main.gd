extends Node2D

@export var pumpkin_scene: PackedScene = preload("res://pumpkin.tscn")
@export var witch_scene: PackedScene = preload("res://witch.tscn")

var squished_count: int = 0
var jack_count: int = 0

const SLOT_WIDTH: float = 36.0 
const MAX_COUNT: int = 9  # Changed to 9 to fit 320px screen width

# Speed Scaling Settings
@export var base_fall_speed: float = 110.0
var current_fall_speed: float = 110.0

var game_active: bool = false
var waiting_for_start: bool = false # Tracks if player can press Space/Enter to start

# Node References ($Start configured as a Button)
@onready var start_button: Button = $Start
@onready var win_label: Label = $YayPumpkins
@onready var lose_label: Label = $LoseLabel
@onready var game_over_label: Label = $GameOverLabel # Reference to Game Over Label
@onready var faster_label: Label = $FasterLabel
@onready var spawn_timer: Timer = $Timer
@onready var witch_timer: Timer = $WitchTimer           # Ensure you have a Timer named WitchTimer in Main
@onready var bat: Area2D = $Player                   # Ensure this matches your Bat/Player node name
@onready var logo: Sprite2D = $Logo                 # Reference to Company Logo Sprite2D

func _ready() -> void:
	randomize()
	current_fall_speed = base_fall_speed
	
	if spawn_timer:
		spawn_timer.timeout.connect(_on_timer_timeout)
		
	if witch_timer:
		witch_timer.timeout.connect(_on_witch_timer_timeout)
		
	if start_button:
		start_button.text = "Touch to Start (or press Space)"
		start_button.pressed.connect(_on_start_pressed)
		
	reset_ui()
	if start_button: 
		start_button.hide()
	
	play_splash_sequence()

func _unhandled_input(event: InputEvent) -> void:
	# Allow Spacebar or Enter to start the game when waiting at the start screen
	if waiting_for_start and not game_active:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			_on_start_pressed()

# --- SPLASH SCREEN ANIMATION ---

func play_splash_sequence() -> void:
	waiting_for_start = false
	if bat: 
		bat.hide()

	if logo == null:
		if start_button: start_button.show()
		waiting_for_start = true
		return

	logo.centered = true
	logo.offset = Vector2.ZERO

	var target_scale_x: float = 1.0
	if logo.texture:
		var target_pixel_width: float = 320.0 * 0.8
		target_scale_x = target_pixel_width / logo.texture.get_width()

	var target_scale = Vector2(target_scale_x, target_scale_x)

	logo.position = Vector2(160, 90)
	logo.scale = Vector2.ZERO
	logo.rotation = 0.0
	logo.modulate.a = 1.0
	logo.show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(logo, "scale", target_scale, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo, "rotation", TAU * 2.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	await get_tree().create_timer(2.0).timeout

	var fade_tween = create_tween()
	fade_tween.tween_property(logo, "modulate:a", 0.0, 0.8)
	await fade_tween.finished

	logo.hide()
	
	if start_button:
		start_button.show()
	waiting_for_start = true

# --- GAME LOGIC ---

func reset_ui() -> void:
	game_active = false
	if bat: bat.hide()
	if win_label: win_label.hide()
	if lose_label: lose_label.hide()
	if game_over_label: game_over_label.hide()
	if faster_label: faster_label.hide()
	if spawn_timer: spawn_timer.stop()
	if witch_timer: witch_timer.stop()

func _on_start_pressed() -> void:
	waiting_for_start = false
	if start_button: start_button.hide()
	if win_label: win_label.hide()
	if lose_label: lose_label.hide()
	if game_over_label: game_over_label.hide()
	if faster_label: faster_label.hide()
	
	if bat: 
		bat.show()
		if bat.has_method("reset_to_ground"):
			bat.reset_to_ground()
	
	get_tree().call_group("pumpkins", "queue_free")
	get_tree().call_group("witches", "queue_free")
	
	squished_count = 0
	jack_count = 0
	game_active = true
	
	if spawn_timer:
		spawn_timer.start()
		
	schedule_next_witch_spawn(true) # Pass true so the first witch spawns early (2-5s)

func spawn_pumpkin() -> void:
	if not game_active or pumpkin_scene == null:
		return
		
	var pumpkin = pumpkin_scene.instantiate()
	pumpkin.add_to_group("pumpkins")
	
	if "fall_speed" in pumpkin:
		pumpkin.fall_speed = current_fall_speed + randf_range(-5.0, 5.0)
		
	var random_x: float = randf_range(18.0, 320.0 - 18.0)
	pumpkin.position = Vector2(random_x, -16.0)
	add_child(pumpkin)

func _on_timer_timeout() -> void:
	spawn_pumpkin()

# --- WITCH SPAWNING LOGIC ---

func schedule_next_witch_spawn(is_first_spawn: bool = false) -> void:
	if witch_timer and game_active:
		if is_first_spawn:
			# Early appearance: 2.0 to 5.0 seconds after game start
			witch_timer.wait_time = randf_range(2.0, 5.0)
		else:
			# Subsequent appearances: 8.0 to 15.0 seconds
			witch_timer.wait_time = randf_range(8.0, 15.0)
		witch_timer.start()

func spawn_witch() -> void:
	if not game_active or witch_scene == null:
		return
		
	var witch = witch_scene.instantiate()
	witch.add_to_group("witches")
	add_child(witch)

func _on_witch_timer_timeout() -> void:
	spawn_witch()
	schedule_next_witch_spawn(false)

# --- STACK REGISTRATION FUNCTIONS ---

func register_jackolantern(pumpkin: Area2D) -> void:
	if not game_active:
		return
		
	if jack_count < MAX_COUNT:
		jack_count += 1
		# Center alignment calculation for 9 items at 36px width
		var target_x: float = 16.0 + ((jack_count - 1) * SLOT_WIDTH)
		var target_y: float = 12.0
		
		pumpkin.target_position = Vector2(target_x, target_y)
		
		if jack_count >= MAX_COUNT:
			game_active = false
			if spawn_timer: spawn_timer.stop()
			if witch_timer: witch_timer.stop()
			clear_falling_pumpkins()
			check_victory()
	else:
		pumpkin.queue_free()

func register_squished_pumpkin(pumpkin: Area2D) -> void:
	if not game_active:
		pumpkin.queue_free()
		return
		
	if squished_count < MAX_COUNT:
		squished_count += 1
		var target_x: float = 320.0 - 16.0 - ((squished_count - 1) * SLOT_WIDTH)
		var target_y: float = 170.0
		
		pumpkin.target_position = Vector2(target_x, target_y)
		
		# Check if this hit reached the limit of 9
		if squished_count >= MAX_COUNT:
			game_active = false
			if spawn_timer: spawn_timer.stop()
			if witch_timer: witch_timer.stop()
			
			# Immediately destroy any other active/falling pumpkins on screen
			clear_falling_pumpkins()
			check_game_over()
	else:
		pumpkin.queue_free()
		
func clear_falling_pumpkins() -> void:
	for node in get_tree().get_nodes_in_group("pumpkins"):
		# Check if the pumpkin is currently stacked/placed in a slot
		var is_placed: bool = false
		if "is_squished" in node and node.is_squished:
			is_placed = true
		if "is_jack" in node and node.is_jack:
			is_placed = true
			
		# If it's not placed in a row yet, it's still mid-air — remove it!
		if not is_placed:
			node.queue_free()

# --- GAME END & SPEED CONTROL ---

func check_game_over() -> void:
	# 1. Show Lose Label
	if lose_label: lose_label.show()
	await get_tree().create_timer(2.0).timeout
	if lose_label: lose_label.hide()
	
	# 2. Show Game Over Label
	if game_over_label: game_over_label.show()
	await get_tree().create_timer(2.5).timeout
	if game_over_label: game_over_label.hide()
	
	# Clear all squished and remaining pumpkins and active witches
	get_tree().call_group("pumpkins", "queue_free")
	get_tree().call_group("witches", "queue_free")
	
	# Reset speed back to base speed
	current_fall_speed = base_fall_speed
	
	# Return to start menu
	reset_ui()
	if start_button: start_button.show()
	waiting_for_start = true

func check_victory() -> void:
	if win_label: win_label.show()
	
	# Increase fall speed by 20% for next level
	current_fall_speed *= 1.20
	
	await get_tree().create_timer(2.0).timeout
	if win_label: win_label.hide()
	
	if faster_label: faster_label.show()
	await get_tree().create_timer(1.5).timeout
	
	_on_start_pressed()
