extends Node2D
var item_scene = preload("res://Scene/Items.tscn")
var lanes = [
	-100.0,
	430.0,
	980.0
]
var spawn_timer := 0.0
var spawn_delay := 4
var score := 100
var max_score := 100

var game_time_limit := 120.0   # 2 menit dalam detik
var game_timer := 0.0
var game_over := false

func _ready():
	randomize()
	update_score_label()

func _process(delta):
	if game_over:
		return

	spawn_timer += delta
	if spawn_timer >= spawn_delay:
		spawn_timer = 0.0
		spawn_item()

	game_timer += delta
	if game_timer >= game_time_limit:
		end_game()

func spawn_item():
	var good_lane = randi() % 3
	for lane in range(3):
		var item = item_scene.instantiate()
		item.target_x = lanes[lane]
		item.position = Vector2(563, 288)
		item.is_good = (lane == good_lane)
		$Items.add_child(item)

func add_score(amount: int):
	if game_over:
		return
	score = min(score + amount, max_score)
	update_score_label()

func subtract_score(amount: int):
	if game_over:
		return
	score -= amount
	update_score_label()
	if score <= 0:
		score = 0
		update_score_label()
		end_game()

func update_score_label():
	$ScoreLabel.text = "Skor: " + str(score)

func end_game():
	if game_over:
		return
	game_over = true

	if score <= 0:
		get_tree().change_scene_to_file("res://Scene/kalah.tscn")
	elif score < 70:
		get_tree().change_scene_to_file("res://Scene/coba_lagi.tscn")
	else:
		get_tree().change_scene_to_file("res://Scene/menang.tscn")

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Klik di posisi: ", event.position)
