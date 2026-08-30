extends Area2D
@export var speed := 0.3
var depth := 0.0
var start_x := 563.0
var target_x := 563.0
var is_good := true

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

func _process(delta):
	depth += speed * delta
	var eased_depth = ease(depth, 1.5)
	var ukuran = lerp(0.15, 2.0, eased_depth)
	scale = Vector2(ukuran, ukuran)
	position.y = lerp(260.0, 587.0, eased_depth)
	position.x = lerp(start_x, target_x, eased_depth)
	if depth >= 1.0:
		queue_free()

func _ready():
	if is_good:
		$Sprite2D.texture = texture_good[randi() % texture_good.size()]
	else:
		$Sprite2D.texture = texture_bad[randi() % texture_bad.size()]
