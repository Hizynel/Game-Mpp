extends Area2D
@export var speed := 0.3
var depth := 0.0
var start_x := 563.0
var target_x := 563.0
var is_good := true

var bob_speed := 10.0
var bob_amount := 15.0
var time_alive := 0.0

var texture_good = [
	preload("res://Asset Game/6.png"),
	preload("res://Asset Game/7.png"),
	preload("res://Asset Game/8.png"),
	preload("res://Asset Game/9.png"),
	preload("res://Asset Game/10.png"),
	preload("res://Asset Game/11.png"),
]
var texture_bad = [
	preload("res://Asset Game/14.png"),
	preload("res://Asset Game/15.png"),
	preload("res://Asset Game/16.png"),
	preload("res://Asset Game/17.png"),
	preload("res://Asset Game/18.png"),
	preload("res://Asset Game/19.png"),
	preload("res://Asset Game/20.png"),
	preload("res://Asset Game/21.png"),
	preload("res://Asset Game/22.png"),
	preload("res://Asset Game/23.png"),
]

func _ready():
	modulate.a = 0.0
	if is_good:
		$Sprite2D.texture = texture_good[randi() % texture_good.size()]
	else:
		$Sprite2D.texture = texture_bad[randi() % texture_bad.size()]

func _process(delta):
	time_alive += delta
	depth += speed * delta
	var eased_depth = ease(depth, 2.0)
	var ukuran = lerp(0.08, 2.0, eased_depth)
	scale = Vector2(ukuran, ukuran)

	var base_y = lerp(234.0, 587.0, eased_depth)
	position.y = base_y + sin(time_alive * bob_speed) * bob_amount * ukuran
	position.x = lerp(start_x, target_x, eased_depth)

	modulate.a = clamp(depth / 0.15, 0.0, 1.0)

	if depth >= 1.0:
		queue_free()
