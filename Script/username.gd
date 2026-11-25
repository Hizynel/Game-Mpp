extends Control

@onready var username_input: LineEdit = $PanelContainer/VBoxContainer/UsernameInput
@onready var password_input: LineEdit = $PanelContainer/VBoxContainer/PasswordInput
@onready var lanjut_button: Button = $PanelContainer/VBoxContainer/LanjutButton
@onready var status_label: Label = $PanelContainer/VBoxContainer/StatusLabel

@onready var btn_preset1: Button = $PanelContainer/VBoxContainer/PresetContainer/BtnPreset1
@onready var btn_preset2: Button = $PanelContainer/VBoxContainer/PresetContainer/BtnPreset2
@onready var btn_preset3: Button = $PanelContainer/VBoxContainer/PresetContainer/BtnPreset3
@onready var btn_preset4: Button = $PanelContainer/VBoxContainer/PresetContainer/BtnPreset4

# Akun uji coba bawaan P2R
const TEST_ACCOUNTS = {
	"saepudin": {
		"email": "saepudin.cihuy@pixel2reality.fun",
		"pass": "saepudin#cihuy-1945"
	},
	"kerupuk": {
		"email": "kang.kerupuk@pixel2reality.fun",
		"pass": "kerupuk#renyah-1945"
	},
	"geprek": {
		"email": "lord.geprek@pixel2reality.fun",
		"pass": "geprek#level99"
	},
	"kentang": {
		"email": "masbro.kentang@pixel2reality.fun",
		"pass": "kentang#crispy-404"
	}
}


func _ready() -> void:
	lanjut_button.pressed.connect(_on_lanjut_pressed)
	status_label.text = ""

	# Default isi akun Saepudin Cihuy
	_fill_preset("saepudin")

	btn_preset1.pressed.connect(func(): _fill_preset("saepudin"))
	btn_preset2.pressed.connect(func(): _fill_preset("kerupuk"))
	btn_preset3.pressed.connect(func(): _fill_preset("geprek"))
	btn_preset4.pressed.connect(func(): _fill_preset("kentang"))


func _fill_preset(key: String) -> void:
	if TEST_ACCOUNTS.has(key):
		username_input.text = TEST_ACCOUNTS[key]["email"]
		password_input.text = TEST_ACCOUNTS[key]["pass"]
		status_label.text = ""


func _on_lanjut_pressed() -> void:
	var identifier = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if identifier == "":
		status_label.text = "⚠️ Email / Username wajib diisi!"
		status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		return

	status_label.text = "Menghubungkan ke API P2R..."
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	lanjut_button.disabled = true

	# Panggil API login
	NetworkManager.login_player(identifier, password, func(success: bool, msg: String, coins: int):
		lanjut_button.disabled = false
		if success:
			status_label.text = "✅ Login Berhasil! Saldo: %d Coins" % coins
			status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			_fade_to_black_and_change_scene("res://Scene/main_menu.tscn")
		else:
			status_label.text = "❌ " + msg
			status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	)


func _fade_to_black_and_change_scene(target_scene: String) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.8).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().change_scene_to_file(target_scene)
