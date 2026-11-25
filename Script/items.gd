extends Area2D
@export var speed := 0.3
@export var lebar_jalur := 1.25 

var depth := 0.0
var start_x := 943.0
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
	var eased_depth = ease(depth, 1.6)
	var ukuran = lerp(0.08, 2.0, eased_depth)
	scale = Vector2(ukuran, ukuran)

	# Lebarkan jarak kiri dan kanan dari titik tengah jalur (913.0)
	var tengah = 913.0
	var start_x_lebar = tengah + (start_x - tengah) * lebar_jalur
	var target_x_lebar = tengah + (target_x - tengah) * lebar_jalur

	# Target Y dinaikkan ke 1150.0 agar item terus melaju keluar layar
	var base_y = lerp(400.0, 1150.0, eased_depth)
	# Pantulan dibatasi agar tidak menahan laju turun item saat membesar
	var pantulan = sin(time_alive * bob_speed) * 6.0 * min(ukuran, 1.0)
	position.y = base_y + pantulan
	position.x = lerp(start_x_lebar, target_x_lebar, eased_depth)

	modulate.a = clamp(depth / 0.15, 0.0, 1.0)

	if depth >= 1.0:
		queue_free()
