extends Node2D

@export var pumpkin_scene: PackedScene = preload("res://pumpkin.tscn")
@export var witch_scene: PackedScene = preload("res://witch.tscn")

var squished_count: int = 0
var jack_count: int = 0

const SLOT_WIDTH: float = 36.0 
const MAX_COUNT: int = 9  # 9 items at 320px width

# Level Tracking
var current_level: int = 1

# Speed Scaling Settings
@export var base_fall_speed: float = 110.0
var current_fall_speed: float = 110.0

var game_active: bool = false
var waiting_for_start: bool = false # Tracks if player can press Space/Enter/Touch to start

# Array of vibrant arcade neon colors for the bat's body
const BAT_BODY_COLORS: Array[Color] = [
	Color("ff0055"), # Electric Hot Pink
	Color("00f0ff"), # Cyberpunk Cyan
	Color("39ff14"), # Neon Lime Green
	Color("ff9900"), # Glowing Amber Orange
	Color("bf00ff"), # Electric Violet / Purple
	Color("ff00aa"), # Neon Magenta
	Color("00ffcc"), # Bright Turquoise / Mint
	Color("ffff00")  # Acid Yellow
]

# Node References
@onready var start_button: Button = $Start
@onready var win_label: Label = $YayPumpkins
@onready var lose_label: Label = $LoseLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var faster_label: Label = $FasterLabel
@onready var spawn_timer: Timer = $Timer
@onready var witch_timer: Timer = $WitchTimer
@onready var bat: Area2D = $Player
@onready var logo: Sprite2D = $Logo
@onready var presents_label: Label = $PresentsLabel if has_node("PresentsLabel") else null

# UI & Mobile Touch Controls
@onready var level_label: Label = $UI/LevelLabel if has_node("UI/LevelLabel") else null
@onready var touch_controls: Control = $UI/TouchControls if has_node("UI/TouchControls") else null

# Giant Pumpkin Boss & Audio References
@onready var giant_pumpkin: AnimatedSprite2D = $GiantPumpkin if has_node("GiantPumpkin") else null
@onready var halloween_music: AudioStreamPlayer = $HalloweenMusic if has_node("HalloweenMusic") else null
@onready var bgm_player: AudioStreamPlayer2D = $BGMPlayer if has_node("BGMPlayer") else null

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
	if waiting_for_start and not game_active:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			_on_start_pressed()

# --- SPLASH SCREEN ANIMATION ---

func play_splash_sequence() -> void:
	waiting_for_start = false
	if bat: bat.hide()
	if touch_controls: touch_controls.hide()
	if presents_label: presents_label.hide()
	if level_label: level_label.hide()

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

	# Shift logo slightly up to make room for text below
	logo.position = Vector2(160, 80)
	logo.scale = Vector2.ZERO
	logo.rotation = 0.0
	logo.modulate.a = 1.0
	logo.show()

	# 1. Spin and scale in the logo
	var tween = create_tween().set_parallel(true)
	tween.tween_property(logo, "scale", target_scale, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo, "rotation", TAU * 2.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished

	# 2. Typewriter Effect for "Presents The Batkins Game"
	if presents_label:
		presents_label.text = "Presents The Batkins Game"
		presents_label.position = Vector2(120, 115) # Position below and slightly right of logo
		presents_label.visible_ratio = 0.0
		presents_label.modulate.a = 1.0
		presents_label.show()

		# Fast typewriter tween over 0.65 seconds
		var typewriter_tween = create_tween()
		typewriter_tween.tween_property(presents_label, "visible_ratio", 1.0, 0.65)
		await typewriter_tween.finished

	await get_tree().create_timer(1.8).timeout

	# 3. Fade out logo and typewriter text together
	var fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property(logo, "modulate:a", 0.0, 0.8)
	if presents_label:
		fade_tween.tween_property(presents_label, "modulate:a", 0.0, 0.8)
		
	await fade_tween.finished

	logo.hide()
	if presents_label: presents_label.hide()
	
	if start_button: start_button.show()
	waiting_for_start = true

# --- GAME LOGIC ---

func reset_ui() -> void:
	game_active = false
	if bat: bat.hide()
	if win_label: win_label.hide()
	if lose_label: lose_label.hide()
	if game_over_label: game_over_label.hide()
	if faster_label: faster_label.hide()
	if presents_label: presents_label.hide()
	if level_label: level_label.hide()
	if spawn_timer: spawn_timer.stop()
	if witch_timer: witch_timer.stop()
	if touch_controls: touch_controls.hide()
	if giant_pumpkin: giant_pumpkin.hide()

func update_level_display() -> void:
	if level_label:
		level_label.text = "Level: " + str(current_level)
		level_label.show()

func _on_start_pressed() -> void:
	waiting_for_start = false
	if start_button: start_button.hide()
	if win_label: win_label.hide()
	if lose_label: lose_label.hide()
	if game_over_label: game_over_label.hide()
	if faster_label: faster_label.hide()
	if presents_label: presents_label.hide()
	
	if touch_controls: touch_controls.show()
	update_level_display()
	
	if bat: 
		bat.show()
		if bat.has_method("reset_to_ground"):
			bat.reset_to_ground()
			
	# Level 1 uses original black; Level 2+ applies random neon color
	if current_level > 1:
		apply_random_bat_color()
	else:
		reset_bat_color()
	
	get_tree().call_group("pumpkins", "queue_free")
	get_tree().call_group("witches", "queue_free")
	
	squished_count = 0
	jack_count = 0
	game_active = true
	
	if spawn_timer:
		spawn_timer.start()
		
	schedule_next_witch_spawn(true)

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
			witch_timer.wait_time = randf_range(2.0, 5.0)
		else:
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
		
		if squished_count >= MAX_COUNT:
			game_active = false
			if spawn_timer: spawn_timer.stop()
			if witch_timer: witch_timer.stop()
			clear_falling_pumpkins()
			check_game_over()
	else:
		pumpkin.queue_free()
		
func clear_falling_pumpkins() -> void:
	for node in get_tree().get_nodes_in_group("pumpkins"):
		var is_placed: bool = false
		if "is_squished" in node and node.is_squished:
			is_placed = true
		if "is_jack" in node and node.is_jack:
			is_placed = true
			
		if not is_placed:
			node.queue_free()

# --- BAT RECOLORING LOGIC ---

func apply_random_bat_color() -> void:
	var bat_node = $Player if has_node("Player") else ($Bat if has_node("Bat") else null)
	if not bat_node:
		return
		
	var animated_sprite: AnimatedSprite2D = null
	if bat_node is AnimatedSprite2D:
		animated_sprite = bat_node
	else:
		for child in bat_node.get_children():
			if child is AnimatedSprite2D:
				animated_sprite = child
				break
				
	if animated_sprite and animated_sprite.material is ShaderMaterial:
		var mat = animated_sprite.material as ShaderMaterial
		var new_color: Color = BAT_BODY_COLORS[randi() % BAT_BODY_COLORS.size()]
		mat.set_shader_parameter("body_color", new_color)

func reset_bat_color() -> void:
	var bat_node = $Player if has_node("Player") else ($Bat if has_node("Bat") else null)
	if not bat_node:
		return
		
	var animated_sprite: AnimatedSprite2D = null
	if bat_node is AnimatedSprite2D:
		animated_sprite = bat_node
	else:
		for child in bat_node.get_children():
			if child is AnimatedSprite2D:
				animated_sprite = child
				break
				
	if animated_sprite and animated_sprite.material is ShaderMaterial:
		var mat = animated_sprite.material as ShaderMaterial
		mat.set_shader_parameter("body_color", Color("000000"))

# --- GAME END & LEVEL CONTROL ---

func check_game_over() -> void:
	if lose_label: lose_label.show()
	await get_tree().create_timer(2.0).timeout
	if lose_label: lose_label.hide()
	
	if game_over_label: game_over_label.show()
	await get_tree().create_timer(2.5).timeout
	if game_over_label: game_over_label.hide()
	
	get_tree().call_group("pumpkins", "queue_free")
	get_tree().call_group("witches", "queue_free")
	
	current_level = 1
	current_fall_speed = base_fall_speed
	reset_bat_color()
	
	reset_ui()
	if start_button: start_button.show()
	waiting_for_start = true

func check_victory() -> void:
	if win_label: win_label.show()
	
	await get_tree().create_timer(1.5).timeout
	if win_label: win_label.hide()
	
	if current_level % 5 == 0:
		await play_giant_pumpkin_sequence()
	
	current_level += 1
	current_fall_speed *= 1.20
	
	if faster_label: faster_label.show()
	await get_tree().create_timer(1.2).timeout
	if faster_label: faster_label.hide()
	
	_on_start_pressed()

# --- GIANT PUMPKIN ANIMATION & MUSIC ---

func play_giant_pumpkin_sequence() -> void:
	if not giant_pumpkin:
		return

	# 1. Fade out & pause standard background music
	var orig_bgm_vol: float = 0.0
	if bgm_player and bgm_player.playing:
		orig_bgm_vol = bgm_player.volume_db
		var bgm_fade = create_tween()
		bgm_fade.tween_property(bgm_player, "volume_db", -80.0, 0.4)
		await bgm_fade.finished
		bgm_player.stream_paused = true

	# Center on viewport
	giant_pumpkin.position = Vector2(160, 90)
	
	# Target scale: A 512px tall texture scaling to fit 180px viewport height
	var target_scale_y: float = 180.0 / 512.0
	var target_scale = Vector2(target_scale_y, target_scale_y)

	# Reset parameters to start tiny (0x0) and transparent
	giant_pumpkin.scale = Vector2.ZERO
	giant_pumpkin.modulate.a = 0.0
	giant_pumpkin.z_index = 100
	giant_pumpkin.show()
	
	if giant_pumpkin.has_method("play"):
		giant_pumpkin.play()

	# 2. Play Boss Halloween Music
	if halloween_music:
		halloween_music.volume_db = 0.0
		halloween_music.play()

	# Zoom in and fade in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(giant_pumpkin, "scale", target_scale, 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(giant_pumpkin, "modulate:a", 1.0, 0.6)

	await tween.finished
	await get_tree().create_timer(2.5).timeout

	# 3. Fade out pumpkin and Halloween music
	var fade_out = create_tween().set_parallel(true)
	fade_out.tween_property(giant_pumpkin, "modulate:a", 0.0, 0.8)
	if halloween_music:
		fade_out.tween_property(halloween_music, "volume_db", -80.0, 0.8)

	await fade_out.finished

	giant_pumpkin.hide()
	if halloween_music:
		halloween_music.stop()
		halloween_music.volume_db = 0.0

	# 4. Resume main background music
	if bgm_player:
		bgm_player.stream_paused = false
		var bgm_fade_in = create_tween()
		bgm_fade_in.tween_property(bgm_player, "volume_db", orig_bgm_vol, 0.8)
