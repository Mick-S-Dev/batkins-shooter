extends Area2D

@export var move_speed: float = 160.0
@export var shoot_speed: float = 350.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var screen_size: Vector2
var ground_y: float
var is_flying: bool = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	ground_y = screen_size.y - 16
	position = Vector2(screen_size.x / 2.0, ground_y)
	sprite.play("idle")
	
	# Connect collision detection signal
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	# Block all movement and input while the Bat is hidden during menus
	if not visible:
		return
		
	if not is_flying:
		# Ground Movement
		var direction := 0.0
		if Input.is_action_pressed("ui_right"):
			direction += 1.0
		if Input.is_action_pressed("ui_left"):
			direction -= 1.0
			
		position.x += direction * move_speed * delta
		position.x = clamp(position.x, 12, screen_size.x - 12)
		
		# Launch Bat
		if Input.is_action_just_pressed("ui_accept"):
			is_flying = true
			sprite.play("fly")
	else:
		# Vertical Flight
		position.y -= shoot_speed * delta
		
		# Reset if missing targets off top screen
		if position.y < -16:
			reset_to_ground()

func _on_area_entered(area: Area2D) -> void:
	# Ignore collisions if the Bat is hidden during menus
	if not visible:
		return
		
	# Convert pumpkin on collision while flying upward
	if is_flying and area.has_method("convert_to_jackolantern"):
		area.convert_to_jackolantern()
		reset_to_ground()

func reset_to_ground() -> void:
	is_flying = false
	position.y = ground_y
	sprite.play("idle")
