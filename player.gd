extends Area2D

@export var move_speed: float = 160.0
@export var shoot_speed: float = 350.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var screen_size: Vector2
var ground_y: float
var is_flying: bool = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Lock initial baseline position near the bottom of the screen
	ground_y = screen_size.y - 16
	position = Vector2(screen_size.x / 2.0, ground_y)
	sprite.play("idle")

func _process(delta: float) -> void:
	if not is_flying:
		# --- GROUNDED STATE ---
		var direction := 0.0
		if Input.is_action_pressed("ui_right"):
			direction += 1.0
		if Input.is_action_pressed("ui_left"):
			direction -= 1.0
			
		position.x += direction * move_speed * delta
		# Clamp within 320px screen borders
		position.x = clamp(position.x, 12, screen_size.x - 12)
		
		# Launch bat on Spacebar
		if Input.is_action_just_pressed("ui_accept"):
			is_flying = true
			sprite.play("fly")
	else:
		# --- FLYING/SHOOTING STATE ---
		position.y -= shoot_speed * delta
		
		# Reset to ground once bat flies off the top edge
		if position.y < -16:
			reset_to_ground()

func reset_to_ground() -> void:
	is_flying = false
	position.y = ground_y
	sprite.play("idle")
