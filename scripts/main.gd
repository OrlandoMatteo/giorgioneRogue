extends Node2D

## A compact, self-contained vertical slice. Visuals are deliberately drawn with
## chunky primitives so the project runs before a texture atlas is imported.

enum GameState { MENU, LEADERBOARD, PLAYING, COOKING, WEAPON_CHOICE, ENDLESS_CHOICE, DINNER, GAME_OVER, PAUSED }

const W := 720.0
const H := 1280.0
const PLAY_TOP := 132.0
const PLAY_BOTTOM := 1055.0
const WORLD_TILE_SIZE := 64.0
const ZONE_DURATION := 150.0
const FINITE_ZONE_COUNT := 5
const WAVES_PER_ZONE := 5
const WAVE_ACTIVE_DURATION := 22.0
const WAVE_BREAK_DURATION := 8.0
const CAPRESE_HEAL_CAP := 0.75
const CAPRESE_ABUNDANT_HEAL_CAP := 0.85
const OBJECTIVE_HEAL := 8.0
const CHEF_IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/chef_walk_v7.png")
const CHEF_ATTACK_TEXTURE: Texture2D = preload("res://assets/sprites/chef_attack_butter_v2.png")
const BUTTER_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/sprites/butter_projectile_v1.png")
const VITELLO_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/sprites/weapon_vitello_tonnato_v1.png")
const UOVA_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/sprites/weapon_uova_purgatorio_v1.png")
const SPAGHETTI_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/sprites/weapon_spaghetti_aglione_v1.png")
const KEGIORG_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/sprites/weapon_kegiorg_v1.png")
const ENEMY_ISPETTORE_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ispettore_walk_v4.png")
const ENEMY_TURISTA_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_turista_walk_v4.png")
const ENEMY_LADRO_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ladro_walk_v4.png")
const ENEMY_ISPETTORE_DEATH_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ispettore_death_v2.png")
const ENEMY_TURISTA_DEATH_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_turista_death_v2.png")
const ENEMY_LADRO_DEATH_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ladro_death_v2.png")
const ENEMY_ANIMATION_FRAMES := 8
const DROP_GUANCIALE_TEXTURE: Texture2D = preload("res://assets/sprites/drop_guanciale_v1.png")
const DROP_OLIO_TEXTURE: Texture2D = preload("res://assets/sprites/drop_olio_v1.png")
const CHEF_FRAME_SIZE := Vector2(128, 128)
const CHEF_ANIMATION_FRAMES := 8
const CHEF_DRAW_SIZE := 124.0
const CHEF_ATTACK_DURATION := 0.28
const WALK_ANIMATION_FPS := 7.0
const ENEMY_COLLISION_SCALE := 1.14
const DIFFICULTY_THRESHOLDS := [0, 10, 25, 45, 70]
const DIFFICULTY_NAMES := ["ASSAGGIO", "BIS", "ABBONDANZA", "LAIDA", "LAIDA E CORROTTA"]
const ZONES := ["L'Orto", "Bosco dei Funghi", "Vigneto", "Fattoria", "Festa in Piazza", "Sagra Infinita"]
const ZONE_COLORS := [
	Color("#78933a"), Color("#4f7044"), Color("#7a4b3a"),
	Color("#a47a43"), Color("#c17a45"), Color("#493453"),
]
const INGREDIENT_LABELS := {
	"pomodoro": "Pomodori", "fungo": "Funghi", "erbe": "Erbe",
	"maiale": "Maiale", "formaggio": "Pecorino", "vino": "Vino",
	"farina": "Farina", "basilico": "Basilico", "mozzarella": "Mozzarella", "uovo": "Uova",
	"guanciale": "Guanciale", "olio": "Olio EVO",
}
const INGREDIENT_COLORS := {
	"pomodoro": Color("#e94d38"), "fungo": Color("#ad733e"), "erbe": Color("#55a934"),
	"maiale": Color("#d47a73"), "formaggio": Color("#f4c34f"), "vino": Color("#7d1e32"),
	"farina": Color("#f5e2a5"), "basilico": Color("#2f7d31"), "mozzarella": Color("#fff4d8"), "uovo": Color("#fff8bf"),
	"guanciale": Color("#d77e72"), "olio": Color("#b89a2f"),
}

var recipe_catalog = [
	preload("res://data/recipes/caprese.tres"), preload("res://data/recipes/tagliatelle.tres"),
	preload("res://data/recipes/polenta.tres"), preload("res://data/recipes/porchetta.tres"),
]
var enemy_catalog = [
	preload("res://data/enemies/turista.tres"),
	preload("res://data/enemies/ladro.tres"),
	preload("res://data/enemies/ispettore.tres"),
]
var recipe_evolutions := {
	"caprese": [
		{"id": "caprese_abbondante", "name": "Caprese Abbondante", "description": "Cura moderata, ma solo fino all'85% della vita."},
		{"id": "caprese_pungente", "name": "Caprese Pungente", "description": "Cura poco fino al 75% e danneggia i nemici vicini."},
	],
	"tagliatelle": [
		{"id": "tagliatelle_sprint", "name": "Tagliatelle Sprint", "description": "+20% velocità e scatto più lungo."},
		{"id": "tagliatelle_scia", "name": "Scia al Burro", "description": "La scia è più larga e infligge più danni."},
	],
	"polenta": [
		{"id": "polenta_raffica", "name": "Polenta a Raffica", "description": "Spara un proiettile aggiuntivo."},
		{"id": "polenta_gigante", "name": "Polenta Gigante", "description": "+40% danno e proiettili più grandi."},
	],
	"porchetta": [
		{"id": "porchetta_lunga", "name": "Porchetta Lunga", "description": "Rotazione più ampia e potente."},
		{"id": "porchetta_frenetica", "name": "Porchetta Frenetica", "description": "La rotazione colpisce quasi due volte più spesso."},
	],
}
var endless_modifier_catalog := [
	{"id": "doppia_dispensa", "name": "Doppia Dispensa", "description": "Doppi ingredienti, nemici +15% veloci."},
	{"id": "burro_critico", "name": "Burro Critico", "description": "25% colpi critici, nemici +20% danno."},
	{"id": "giganti", "name": "Ospiti Giganti", "description": "Nemici più grandi e resistenti, punti doppi."},
	{"id": "pioggia_burro", "name": "Pioggia di Burro", "description": "Raffica radiale automatica, più nemici."},
]
var weapon_upgrade_catalog := [
	{"id": "vitello_tonnato", "name": "Vitello Tonnato Volante", "description": "Colpo pesante: ogni livello aumenta danno e dimensione."},
	{"id": "uova_purgatorio", "name": "Uova in Purgatorio", "description": "Colpo esplosivo: ogni livello amplia area e danno."},
	{"id": "spaghetti_aglione", "name": "Spaghetti all'Aglione", "description": "Colpo rapido: ogni livello aumenta velocita e perforazione."},
	{"id": "kegiorg", "name": "KeGiorg Rotante", "description": "Colpo rotante: ogni livello aggiunge danno e un bersaglio."},
]

var state := GameState.MENU
var rng := RandomNumberGenerator.new()
var player_pos := Vector2.ZERO
var player_health := 100.0
var player_max_health := 100.0
var player_speed := 220.0
var player_invulnerable := 0.0
var player_facing := 1.0
var player_is_moving := false
var zone_index := 0
var zone_remaining := ZONE_DURATION
var spawn_clock := 0.0
var wave_number := 1
var wave_active := true
var wave_time_remaining := WAVE_ACTIVE_DURATION
var wave_break_remaining := 0.0
var wave_spawn_budget := 0
var wave_spawned := 0
var wave_is_special := false
var attack_clock := 0.0
var attack_animation_time := 0.0
var caprese_clock := 0.0
var porchetta_clock := 0.0
var trail_clock := 0.0
var dash_ready_at := 0.0
var elapsed_run := 0.0
var score := 0
var kills := 0
var difficulty_tier := 0
var attack_sequence := 0
var next_enemy_uid := 1
var endless_mode := false
var endless_elapsed := 0.0
var endless_score_clock := 0.0
var inspector_spawned_this_zone := false
var score_recorded := false
var recipe_levels := {}
var recipe_evolution_choices := {}
var active_endless_modifiers: Array[String] = []
var next_modifier_wave := 3
var weapon_upgrade_levels := {}
var collected_drops := 0
var next_weapon_upgrade_at := 5
var butter_rain_clock := 0.0
var inspection_zones: Array = []
var floating_texts: Array = []
var kill_combo := 0
var combo_clock := 0.0
var objective_kind := ""
var objective_progress := 0
var objective_target := 0
var objective_completed := false
var inventory := {}
var enemies: Array = []
var projectiles: Array = []
var drops: Array = []
var deaths: Array = []
var butter_trails: Array = []
var enemy_pool: Array = []
var projectile_pool: Array = []
var joystick_touch := -1
var joystick_vector := Vector2.ZERO
var joystick_center := Vector2(112, 1140)
var hud: Control
var overlay: Control
var dash_button: Button
var hud_labels := {}
var was_new_best := false
var world_camera: Camera2D
var registration_name_input: LineEdit
var online_status_label: Label
var global_leaderboard_open := false

func _ready() -> void:
	rng.randomize()
	OnlineLeaderboard.registration_completed.connect(_on_online_registration_completed)
	OnlineLeaderboard.leaderboard_loaded.connect(_on_global_leaderboard_loaded)
	world_camera = Camera2D.new()
	world_camera.position = player_pos
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 7.0
	add_child(world_camera)
	world_camera.make_current()
	build_interface()
	show_menu()
	if OnlineLeaderboard.is_configured() and not OnlineLeaderboard.has_identity():
		call_deferred("show_username_registration")
	queue_redraw()

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		update_play(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if state != GameState.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch == -1 and is_joystick_position(event.position):
			joystick_touch = event.index
			joystick_center = event.position
			joystick_vector = Vector2.ZERO
		elif not event.pressed and event.index == joystick_touch:
			joystick_touch = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == joystick_touch:
		joystick_vector = (event.position - joystick_center).limit_length(74.0) / 74.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and joystick_touch == -1 and is_joystick_position(event.position):
			joystick_touch = -2
			joystick_center = event.position
			joystick_vector = Vector2.ZERO
		elif not event.pressed and joystick_touch == -2:
			joystick_touch = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventMouseMotion and joystick_touch == -2:
		joystick_vector = (event.position - joystick_center).limit_length(74.0) / 74.0

func is_joystick_position(position: Vector2) -> bool:
	var viewport_width: float = get_viewport_rect().size.x
	var activation_width: float = minf(viewport_width * 0.5, 320.0)
	return position.x <= activation_width

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	var top := make_panel(Rect2(12, 12, 696, 106), Color("#24321d"), Color("#f3d47c"))
	hud.add_child(top)
	hud_labels.zone = make_label(Vector2(28, 19), Vector2(330, 34), 20, HORIZONTAL_ALIGNMENT_LEFT)
	hud_labels.timer = make_label(Vector2(365, 19), Vector2(180, 34), 25, HORIZONTAL_ALIGNMENT_RIGHT)
	hud_labels.health = make_label(Vector2(28, 54), Vector2(210, 34), 21, HORIZONTAL_ALIGNMENT_LEFT)
	hud_labels.score = make_label(Vector2(218, 54), Vector2(190, 34), 18, HORIZONTAL_ALIGNMENT_CENTER)
	hud_labels.pantry = make_label(Vector2(410, 51), Vector2(275, 42), 16, HORIZONTAL_ALIGNMENT_RIGHT)
	for label in hud_labels.values():
		top.add_child(label)
	hud_labels.objective = make_label(Vector2(18, 120), Vector2(510, 34), 15, HORIZONTAL_ALIGNMENT_LEFT)
	hud_labels.objective.add_theme_color_override("font_color", Color("#fff0a8"))
	hud.add_child(hud_labels.objective)

	var pause := make_button("II", Rect2(645, 22, 52, 42), 22)
	pause.tooltip_text = "Pausa"
	pause.pressed.connect(toggle_pause)
	hud.add_child(pause)
	dash_button = make_button("SCATTO", Rect2(552, 1080, 144, 144), 20)
	dash_button.tooltip_text = "Scatto / interazione"
	dash_button.pressed.connect(dash)
	hud.add_child(dash_button)

func make_panel(rect: Rect2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func make_label(position: Vector2, size: Vector2, font_size: int, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff4d6"))
	return label

func make_button(text_value: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#fff4d6"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#a84c27")
	normal.border_color = Color("#f3d47c")
	normal.set_border_width_all(3)
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#73341d")
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func clear_overlay() -> void:
	for child in overlay.get_children():
		child.queue_free()

func show_menu() -> void:
	state = GameState.MENU
	global_leaderboard_open = false
	hud.visible = false
	clear_overlay()
	var panel := make_panel(Rect2(48, 210, 624, 800), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var title := make_label(Vector2(28, 42), Vector2(568, 122), 52)
	title.text = "GIORGIONE'S\nFEAST"
	title.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(title)
	var subtitle := make_label(Vector2(52, 158), Vector2(520, 90), 20)
	subtitle.text = "Cinque scenari, miniboss e Sagra Infinita.\nRaccogli, cucina e conquista la classifica."
	panel.add_child(subtitle)
	var start := make_button("INIZIA LA SAGRA", Rect2(78, 260, 468, 68), 24)
	start.pressed.connect(start_run)
	panel.add_child(start)
	var leaderboard_button := make_button("CLASSIFICA LOCALE", Rect2(78, 345, 468, 58), 19)
	leaderboard_button.pressed.connect(show_leaderboard)
	panel.add_child(leaderboard_button)
	var global_button := make_button("CLASSIFICA MONDIALE", Rect2(78, 420, 468, 58), 19)
	global_button.disabled = not OnlineLeaderboard.is_configured()
	global_button.pressed.connect(show_global_leaderboard)
	panel.add_child(global_button)
	var identity_text := "REGISTRA NOME GIOCATORE"
	if OnlineLeaderboard.has_identity():
		identity_text = "GIOCATORE: %s" % OnlineLeaderboard.current_username().to_upper()
	elif not OnlineLeaderboard.is_configured():
		identity_text = "CONFIGURA CLASSIFICA ONLINE"
	var identity_button := make_button(identity_text, Rect2(78, 495, 468, 58), 18)
	identity_button.pressed.connect(show_username_registration)
	panel.add_child(identity_button)
	var best := make_label(Vector2(58, 570), Vector2(508, 45), 18)
	best.text = "Miglior cena: %d punti" % int(SaveData.data.best_score)
	panel.add_child(best)
	var note := make_label(Vector2(48, 655), Vector2(528, 84), 14)
	note.text = "Opera fan non ufficiale.\nTocca e trascina a sinistra per muoverti."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#d4e0bd"))
	panel.add_child(note)

func show_username_registration() -> void:
	state = GameState.LEADERBOARD
	global_leaderboard_open = false
	hud.visible = false
	clear_overlay()
	var panel := make_panel(Rect2(70, 300, 580, 650), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(25, 28), Vector2(530, 65), 31)
	heading.text = "GIOCATORE ONLINE"
	panel.add_child(heading)
	var explanation := make_label(Vector2(45, 105), Vector2(490, 90), 17)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if OnlineLeaderboard.has_identity():
		explanation.text = "Registrato come %s. Il nome resta salvato su questo dispositivo." % OnlineLeaderboard.current_username()
	else:
		explanation.text = "Inserisci un nome. Se esiste già verrà selezionato; altrimenti sarà creato."
	panel.add_child(explanation)
	registration_name_input = LineEdit.new()
	registration_name_input.position = Vector2(65, 220)
	registration_name_input.size = Vector2(450, 62)
	registration_name_input.placeholder_text = "Nome giocatore (3-20 caratteri)"
	registration_name_input.text = OnlineLeaderboard.current_username()
	registration_name_input.max_length = 20
	registration_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	registration_name_input.add_theme_font_size_override("font_size", 20)
	panel.add_child(registration_name_input)
	online_status_label = make_label(Vector2(55, 295), Vector2(470, 65), 16)
	online_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	online_status_label.text = "" if OnlineLeaderboard.is_configured() else "Completa prima online/leaderboard_config.json."
	panel.add_child(online_status_label)
	var confirm := make_button("USA QUESTO NOME", Rect2(85, 380, 410, 62), 20)
	confirm.disabled = not OnlineLeaderboard.is_configured()
	confirm.pressed.connect(submit_username_registration)
	panel.add_child(confirm)
	if OnlineLeaderboard.has_identity():
		var reset := make_button("DIMENTICA GIOCATORE", Rect2(85, 460, 410, 58), 17)
		reset.pressed.connect(reset_online_identity)
		panel.add_child(reset)
	var back := make_button("TORNA AL MENU", Rect2(125, 545, 330, 58), 18)
	back.pressed.connect(show_menu)
	panel.add_child(back)
	registration_name_input.grab_focus()

func submit_username_registration() -> void:
	if registration_name_input == null or online_status_label == null:
		return
	online_status_label.text = "Connessione..."
	OnlineLeaderboard.register_username(registration_name_input.text)

func reset_online_identity() -> void:
	SaveData.clear_online_identity()
	show_menu()

func _on_online_registration_completed(success: bool, message: String) -> void:
	if success:
		show_menu()
	elif online_status_label != null and is_instance_valid(online_status_label):
		online_status_label.text = message

func show_global_leaderboard() -> void:
	state = GameState.LEADERBOARD
	global_leaderboard_open = true
	hud.visible = false
	render_global_leaderboard([], "Caricamento classifica...")
	OnlineLeaderboard.fetch_global_leaderboard()

func _on_global_leaderboard_loaded(success: bool, entries: Array, message: String) -> void:
	if state != GameState.LEADERBOARD or not global_leaderboard_open:
		return
	render_global_leaderboard(entries if success else [], message)

func render_global_leaderboard(entries: Array, message: String) -> void:
	clear_overlay()
	var panel := make_panel(Rect2(38, 135, 644, 990), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(25, 28), Vector2(594, 68), 34)
	heading.text = "CLASSIFICA MONDIALE"
	heading.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(heading)
	var identity := make_label(Vector2(35, 92), Vector2(574, 34), 15)
	identity.text = "Giocatore: %s" % (OnlineLeaderboard.current_username() if OnlineLeaderboard.has_identity() else "non registrato")
	panel.add_child(identity)
	var header := make_label(Vector2(30, 135), Vector2(584, 35), 15, HORIZONTAL_ALIGNMENT_LEFT)
	header.text = "POS  NOME                 PUNTI       KO     INF."
	header.add_theme_color_override("font_color", Color("#d4e0bd"))
	panel.add_child(header)
	if entries.is_empty():
		var status := make_label(Vector2(50, 230), Vector2(544, 100), 19)
		status.text = message if not message.is_empty() else "Nessun punteggio online."
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(status)
	else:
		for index in range(mini(12, entries.size())):
			var entry: Dictionary = entries[index]
			var endless_seconds := int(entry.get("endless_seconds", 0))
			var endless_text := "--"
			if endless_seconds > 0:
				endless_text = "%02d:%02d" % [floori(endless_seconds / 60.0), endless_seconds % 60]
			var row := make_label(Vector2(30, 178 + index * 54), Vector2(584, 44), 16, HORIZONTAL_ALIGNMENT_LEFT)
			row.text = "%2d.  %-18s %8d   %4d   %s" % [
				int(entry.get("rank", index + 1)), String(entry.get("username", "?")).left(18),
				int(entry.get("best_score", 0)), int(entry.get("kills", 0)), endless_text,
			]
			if String(entry.get("username", "")).nocasecmp_to(OnlineLeaderboard.current_username()) == 0:
				row.add_theme_color_override("font_color", Color("#f5cb56"))
			panel.add_child(row)
	var back := make_button("TORNA AL MENU", Rect2(102, 870, 440, 66), 21)
	back.pressed.connect(show_menu)
	panel.add_child(back)

func show_leaderboard() -> void:
	state = GameState.LEADERBOARD
	global_leaderboard_open = false
	hud.visible = false
	clear_overlay()
	var panel := make_panel(Rect2(48, 150, 624, 950), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(28, 30), Vector2(568, 70), 36)
	heading.text = "CLASSIFICA LOCALE"
	heading.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(heading)
	var header := make_label(Vector2(42, 112), Vector2(540, 38), 16, HORIZONTAL_ALIGNMENT_LEFT)
	header.text = "POS   PUNTI       KO       ZONE       INFINITA"
	header.add_theme_color_override("font_color", Color("#d4e0bd"))
	panel.add_child(header)
	var entries: Array = SaveData.get_leaderboard()
	if entries.is_empty():
		var empty := make_label(Vector2(55, 250), Vector2(514, 90), 21)
		empty.text = "Nessun risultato.\nLa prima sagra aspetta te!"
		panel.add_child(empty)
	else:
		for index in range(mini(10, entries.size())):
			var entry: Dictionary = entries[index]
			var row := make_label(Vector2(42, 165 + index * 58), Vector2(540, 48), 17, HORIZONTAL_ALIGNMENT_LEFT)
			var endless_seconds: int = int(entry.get("endless_seconds", 0))
			var endless_text := "--"
			if endless_seconds > 0:
				endless_text = "%02d:%02d" % [endless_seconds / 60, endless_seconds % 60]
			row.text = "%2d.   %7d     %4d        %d/5         %s" % [
				index + 1, int(entry.get("score", 0)), int(entry.get("kills", 0)),
				int(entry.get("zones", 0)), endless_text,
			]
			if index == 0:
				row.add_theme_color_override("font_color", Color("#f5cb56"))
			panel.add_child(row)
	var back := make_button("TORNA AL MENU", Rect2(92, 820, 440, 70), 22)
	back.pressed.connect(show_menu)
	panel.add_child(back)

func start_run() -> void:
	RunState.begin_run()
	state = GameState.PLAYING
	hud.visible = true
	clear_overlay()
	player_pos = Vector2.ZERO
	player_facing = 1.0
	player_is_moving = false
	world_camera.position = player_pos
	world_camera.reset_smoothing()
	player_health = player_max_health
	zone_index = 0
	zone_remaining = ZONE_DURATION
	spawn_clock = 0.8
	attack_clock = 0.2
	attack_animation_time = 0.0
	caprese_clock = 0.0
	porchetta_clock = 0.0
	trail_clock = 0.0
	elapsed_run = 0.0
	score = 0
	kills = 0
	difficulty_tier = 0
	attack_sequence = 0
	next_enemy_uid = 1
	endless_mode = false
	endless_elapsed = 0.0
	endless_score_clock = 0.0
	inspector_spawned_this_zone = false
	score_recorded = false
	recipe_levels.clear()
	recipe_evolution_choices.clear()
	active_endless_modifiers.clear()
	next_modifier_wave = 3
	weapon_upgrade_levels.clear()
	collected_drops = 0
	next_weapon_upgrade_at = 5
	butter_rain_clock = 0.0
	inspection_zones.clear()
	floating_texts.clear()
	kill_combo = 0
	combo_clock = 0.0
	for key in INGREDIENT_LABELS:
		inventory[key] = 1
	enemies.clear()
	projectiles.clear()
	drops.clear()
	deaths.clear()
	butter_trails.clear()
	was_new_best = false
	setup_zone_objective()
	begin_wave(1)
	AudioManager.play_music("campagna")
	update_hud()

func update_play(delta: float) -> void:
	elapsed_run += delta
	combo_clock = maxf(0.0, combo_clock - delta)
	if combo_clock <= 0.0:
		kill_combo = 0
	if endless_mode:
		endless_elapsed += delta
		endless_score_clock += delta
		if endless_score_clock >= 1.0:
			var scored_seconds := floori(endless_score_clock)
			score += scored_seconds * (5 + endless_wave() * 2)
			endless_score_clock -= scored_seconds
	else:
		zone_remaining -= delta
	player_invulnerable = maxf(0.0, player_invulnerable - delta)
	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	var direction := keyboard_direction()
	if joystick_touch != -1:
		direction = joystick_vector
	player_is_moving = direction.length() > 0.05
	if player_is_moving:
		var movement_direction: Vector2 = direction.normalized()
		if absf(movement_direction.x) > 0.05:
			player_facing = signf(movement_direction.x)
		var speed_multiplier := 1.0 + 0.25 * int(recipe_levels.get("tagliatelle", 0))
		if recipe_evolution_choices.get("tagliatelle", "") == "tagliatelle_sprint":
			speed_multiplier += 0.20
		player_pos += movement_direction * player_speed * speed_multiplier * delta
	world_camera.position = player_pos
	update_wave_director(delta)
	attack_clock -= delta
	if attack_clock <= 0.0:
		if auto_attack():
			attack_clock = maxf(0.24, 0.68 - 0.08 * int(recipe_levels.get("polenta", 0)))
		else:
			# Poll quickly without wasting a full firing cooldown while the screen is clear.
			attack_clock = 0.08
	update_recipe_effects(delta)
	update_enemies(delta)
	update_projectiles(delta)
	update_drops(delta)
	update_trails(delta)
	update_deaths(delta)
	update_inspection_zones(delta)
	update_floating_texts(delta)
	update_butter_rain(delta)
	if player_health <= 0.0:
		show_game_over()
	elif state == GameState.PLAYING and collected_drops >= next_weapon_upgrade_at:
		show_weapon_upgrade_choice()
	elif state == GameState.PLAYING and endless_mode and endless_wave() >= next_modifier_wave:
		show_endless_modifier_choice()
	update_hud()

func keyboard_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1.0
	return direction.normalized()

func spawn_enemy() -> void:
	var options: Array = []
	match zone_index:
		0:
			options = [enemy_catalog[0], enemy_catalog[1]]
		1:
			options = [enemy_catalog[1], enemy_catalog[1], enemy_catalog[0]]
		2:
			options = [enemy_catalog[0], enemy_catalog[0], enemy_catalog[1]]
		3:
			options = [enemy_catalog[1], enemy_catalog[0], enemy_catalog[1]]
		4:
			options = [enemy_catalog[0], enemy_catalog[1], enemy_catalog[0]]
		_:
			options = [enemy_catalog[0], enemy_catalog[1]]
	var data: EnemyData = options[rng.randi_range(0, options.size() - 1)]
	spawn_enemy_data(data)

func spawn_enemy_data(data: EnemyData) -> Dictionary:
	var side := rng.randi_range(0, 3)
	var center: Vector2 = get_camera_center()
	var half_view := Vector2(W * 0.5, H * 0.5)
	var margin := 64.0
	var position := Vector2(rng.randf_range(center.x - half_view.x, center.x + half_view.x), center.y - half_view.y - margin)
	if side == 1: position = Vector2(center.x + half_view.x + margin, rng.randf_range(center.y - half_view.y, center.y + half_view.y))
	if side == 2: position = Vector2(rng.randf_range(center.x - half_view.x, center.x + half_view.x), center.y + half_view.y + margin)
	if side == 3: position = Vector2(center.x - half_view.x - margin, rng.randf_range(center.y - half_view.y, center.y + half_view.y))
	var enemy: Dictionary = acquire_enemy()
	enemy.uid = next_enemy_uid
	next_enemy_uid += 1
	enemy.data = data
	enemy.pos = position
	var endless_scale := maxf(0.0, float(endless_wave() - 1)) if endless_mode else 0.0
	var zone_scale: float = float(zone_index) * 0.08
	var wave_scale: float = float(maxi(0, wave_number - 1)) * 0.04
	enemy.max_hp = data.max_health * (1.35 + zone_scale + wave_scale + difficulty_tier * 0.16 + endless_scale * 0.12)
	enemy.visual_scale = 1.0
	if "giganti" in active_endless_modifiers:
		enemy.max_hp *= 1.55
		enemy.visual_scale = 1.28
	if data.id == "ispettore":
		enemy.max_hp *= 1.35 + minf(0.75, zone_index * 0.12)
	enemy.hp = enemy.max_hp
	enemy.speed_scale = 1.0 + difficulty_tier * 0.055 + minf(0.45, endless_scale * 0.035)
	enemy.damage_scale = 1.12 + zone_scale * 0.45 + wave_scale * 0.35 + difficulty_tier * 0.085 + endless_scale * 0.07
	if "doppia_dispensa" in active_endless_modifiers:
		enemy.speed_scale *= 1.15
	if "burro_critico" in active_endless_modifiers:
		enemy.damage_scale *= 1.20
	enemy.hit_flash = 0.0
	enemy.touch_clock = 0.0
	enemy.behavior_clock = rng.randf_range(1.2, 3.5)
	enemy.charge_time = 0.0
	enemy.escape_time = 0.0
	enemy.ability_clock = 3.5
	enemy.phase_two = false
	enemy.facing = -1.0 if player_pos.x < enemy.pos.x else 1.0
	enemy.role_title = ""
	if data.id == "ispettore":
		enemy.role_title = "CARDIOLOGO" if rng.randi_range(0, 1) == 0 else "DIETOLOGO"
	enemies.append(enemy)
	return enemy

func endless_wave() -> int:
	return wave_number

func begin_wave(number: int) -> void:
	wave_number = number
	wave_active = true
	wave_time_remaining = WAVE_ACTIVE_DURATION
	wave_break_remaining = 0.0
	wave_spawned = 0
	wave_is_special = number % 3 == 0
	if wave_is_special:
		# The specialist is the focus: only a small escort is spawned.
		var escort_target: int = 3 + floori(float(zone_index) / 2.0) if not endless_mode else 4 + floori(float(number) / 3.0)
		var existing_normal_enemies := 0
		for active_enemy in enemies:
			if String(active_enemy.data.id) != "ispettore":
				existing_normal_enemies += 1
		wave_spawn_budget = maxi(0, escort_target - existing_normal_enemies)
		if not has_inspector():
			var specialist: Dictionary = spawn_enemy_data(enemy_catalog[2])
			add_floating_text("ARRIVA IL %s!" % String(specialist.role_title), player_pos + Vector2(0, -125), Color("#ffb84d"))
	else:
		wave_spawn_budget = 8 + zone_index * 2 + (number - 1) * 2 + difficulty_tier
		if endless_mode:
			wave_spawn_budget = 10 + number * 2 + difficulty_tier
	spawn_clock = 0.55
	add_floating_text("ONDA %d" % number, player_pos + Vector2(0, -90), Color("#fff06a"))

func update_wave_director(delta: float) -> void:
	if wave_active:
		wave_time_remaining = maxf(0.0, wave_time_remaining - delta)
		spawn_clock -= delta
		if spawn_clock <= 0.0 and wave_spawned < wave_spawn_budget:
			var enemy_limit: int = 70 if endless_mode else 55
			if enemies.size() < enemy_limit:
				spawn_enemy()
				wave_spawned += 1
			var remaining_spawns: int = maxi(1, wave_spawn_budget - wave_spawned)
			spawn_clock = maxf(0.58, wave_time_remaining / float(remaining_spawns + 1))
		if wave_time_remaining <= 0.0:
			wave_active = false
			wave_break_remaining = WAVE_BREAK_DURATION
			add_floating_text("RESPIRO!", player_pos + Vector2(0, -90), Color("#bfe8ff"))
		return
	wave_break_remaining = maxf(0.0, wave_break_remaining - delta)
	if wave_break_remaining > 0.0:
		return
	if not endless_mode and wave_number >= WAVES_PER_ZONE:
		finish_zone()
	else:
		begin_wave(wave_number + 1)

func has_inspector() -> bool:
	for enemy in enemies:
		if enemy.data.id == "ispettore":
			return true
	return false

func acquire_enemy() -> Dictionary:
	if not enemy_pool.is_empty():
		return enemy_pool.pop_back()
	return {}

func release_enemy(enemy: Dictionary) -> void:
	enemy_pool.append(enemy)

func auto_attack() -> bool:
	var target: Dictionary = {}
	var closest := INF
	for enemy in enemies:
		if not enemy_is_in_viewport(enemy):
			continue
		var distance: float = player_pos.distance_squared_to(enemy.pos as Vector2)
		if distance < closest:
			closest = distance
			target = enemy
	if target.is_empty():
		return false
	var base_direction: Vector2 = (target.pos - player_pos).normalized()
	var shot_count: int = 2 if difficulty_tier >= 4 else 1
	if recipe_evolution_choices.get("polenta", "") == "polenta_raffica":
		shot_count += 1
	if int(inventory.get("guanciale", 0)) >= 5 and attack_sequence % 3 == 0:
		shot_count += 1
	for shot in range(shot_count):
		var angle_offset: float = (shot - (shot_count - 1) * 0.5) * 0.16
		spawn_food_projectile(projectile_kind_for_shot(shot), base_direction.rotated(angle_offset))
	attack_sequence += 1
	attack_animation_time = CHEF_ATTACK_DURATION
	AudioManager.play_sfx("burro")
	return true

func enemy_is_in_viewport(enemy: Dictionary) -> bool:
	var center: Vector2 = get_camera_center()
	var visible_rect := Rect2(center - Vector2(W, H) * 0.5, Vector2(W, H))
	var visual_margin: float = maxf(24.0, float(enemy.data.radius) * float(enemy.get("visual_scale", 1.0)))
	return visible_rect.grow(visual_margin).has_point(enemy.pos)

func projectile_kind_for_shot(shot: int) -> String:
	var unlocked: Array[String] = ["burro"]
	for weapon_id in ["vitello_tonnato", "uova_purgatorio", "spaghetti_aglione", "kegiorg"]:
		if int(weapon_upgrade_levels.get(weapon_id, 0)) > 0:
			unlocked.append(weapon_id)
	return unlocked[(attack_sequence + shot) % unlocked.size()]

func spawn_food_projectile(kind: String, direction: Vector2) -> void:
	var projectile: Dictionary = acquire_projectile()
	var polenta_level: int = int(recipe_levels.get("polenta", 0))
	var weapon_level: int = maxi(1, int(weapon_upgrade_levels.get(kind, 0)))
	projectile.kind = kind
	projectile.weapon_level = weapon_level
	projectile.pos = player_pos
	projectile.velocity = direction * (460.0 + 30.0 * polenta_level)
	projectile.life = 1.75
	projectile.spin_offset = rng.randi_range(0, 3)
	projectile.hit_uids = []
	projectile.splash_radius = 0.0
	projectile.splash_damage = 0.0
	projectile.critical = "burro_critico" in active_endless_modifiers and rng.randf() < 0.25
	match kind:
		"vitello_tonnato":
			projectile.damage = 30.0 + 9.0 * (weapon_level - 1) + 6.0 * polenta_level
			projectile.radius = 18.0 + 2.0 * weapon_level + 2.0 * polenta_level
			projectile.hits_left = 1
		"uova_purgatorio":
			projectile.damage = 19.0 + 5.0 * weapon_level + 5.0 * polenta_level
			projectile.radius = 15.0 + 1.5 * weapon_level + 2.0 * polenta_level
			projectile.hits_left = 1
			projectile.splash_radius = 52.0 + 10.0 * weapon_level + 4.0 * polenta_level
			projectile.splash_damage = 11.0 + 6.0 * weapon_level + 4.0 * polenta_level
		"spaghetti_aglione":
			projectile.damage = 17.0 + 5.0 * weapon_level + 5.0 * polenta_level
			projectile.radius = 14.0 + 1.5 * weapon_level + 2.0 * polenta_level
			projectile.hits_left = 1 + ceili(float(weapon_level) / 2.0)
			projectile.velocity *= 1.25 + 0.08 * weapon_level
		"kegiorg":
			projectile.damage = 23.0 + 7.0 * weapon_level + 5.0 * polenta_level
			projectile.radius = 18.0 + 2.0 * weapon_level + 2.0 * polenta_level
			projectile.hits_left = 1 + weapon_level
		_:
			projectile.damage = 17.0 + difficulty_tier * 3.0 + 6.0 * polenta_level
			projectile.radius = 13.0 + difficulty_tier + 2.0 * polenta_level
			projectile.hits_left = 1
	if difficulty_tier >= 4:
		projectile.damage *= 1.10
	if recipe_evolution_choices.get("polenta", "") == "polenta_gigante":
		projectile.damage *= 1.40
		projectile.radius *= 1.28
	if int(inventory.get("olio", 0)) >= 5:
		projectile.splash_radius = maxf(float(projectile.splash_radius), 54.0)
		projectile.splash_damage = maxf(float(projectile.splash_damage), float(projectile.damage) * 0.35)
	if bool(projectile.critical):
		projectile.damage *= 2.0
	projectiles.append(projectile)

func acquire_projectile() -> Dictionary:
	if not projectile_pool.is_empty():
		return projectile_pool.pop_back()
	return {}

func release_projectile(projectile: Dictionary) -> void:
	projectile_pool.append(projectile)

func update_enemies(delta: float) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		enemy.hit_flash = maxf(0.0, float(enemy.hit_flash) - delta)
		enemy.touch_clock = maxf(0.0, float(enemy.touch_clock) - delta)
		enemy.behavior_clock = float(enemy.get("behavior_clock", 1.0)) - delta
		enemy.charge_time = maxf(0.0, float(enemy.get("charge_time", 0.0)) - delta)
		enemy.escape_time = maxf(0.0, float(enemy.get("escape_time", 0.0)) - delta)
		var direction: Vector2 = (player_pos - enemy.pos).normalized()
		var movement_multiplier := 1.0
		match String(enemy.data.id):
			"turista":
				if float(enemy.behavior_clock) <= 0.0:
					enemy.charge_time = 0.72
					enemy.behavior_clock = rng.randf_range(3.2, 4.8)
				if float(enemy.charge_time) > 0.0:
					movement_multiplier = 2.25
			"ladro":
				if float(enemy.escape_time) > 0.0:
					direction = (enemy.pos - player_pos).normalized()
					movement_multiplier = 1.65
				else:
					var drop_index := nearest_drop_index(enemy.pos, 290.0)
					if drop_index >= 0:
						direction = (drops[drop_index].pos - enemy.pos).normalized()
						movement_multiplier = 1.32
						if enemy.pos.distance_to(drops[drop_index].pos) < 34.0:
							drops.remove_at(drop_index)
							enemy.escape_time = 2.5
							add_floating_text("RUBATO!", enemy.pos, Color("#f2b84b"))
			"ispettore":
				var health_ratio: float = float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
				if health_ratio <= 0.5 and not bool(enemy.phase_two):
					enemy.phase_two = true
					add_floating_text("CONTROLLO SEVERO!", enemy.pos + Vector2(0, -90), Color("#ff6b57"))
				if bool(enemy.phase_two):
					movement_multiplier = 1.28
				enemy.ability_clock = float(enemy.get("ability_clock", 2.0)) - delta
				if float(enemy.ability_clock) <= 0.0:
					create_inspection_zone(player_pos)
					if bool(enemy.phase_two):
						create_inspection_zone(player_pos + Vector2(rng.randf_range(-105, 105), rng.randf_range(-105, 105)))
					enemy.ability_clock = 2.8 if bool(enemy.phase_two) else 4.4
		if absf(direction.x) > 0.05:
			enemy.facing = signf(direction.x)
		enemy.pos += direction * enemy.data.speed * float(enemy.get("speed_scale", 1.0)) * movement_multiplier * delta
		var collision_radius: float = enemy.data.radius * ENEMY_COLLISION_SCALE * float(enemy.get("visual_scale", 1.0))
		if enemy.pos.distance_to(player_pos) < collision_radius + 20.0 and enemy.touch_clock <= 0.0:
			damage_player(enemy.data.contact_damage * float(enemy.get("damage_scale", 1.0)))
			enemy.touch_clock = 0.7
		if enemy.hp <= 0.0:
			defeat_enemy(index)

func nearest_drop_index(origin: Vector2, maximum_distance: float) -> int:
	var result := -1
	var closest_squared := maximum_distance * maximum_distance
	for index in range(drops.size()):
		var distance_squared: float = origin.distance_squared_to(drops[index].pos)
		if distance_squared < closest_squared:
			closest_squared = distance_squared
			result = index
	return result

func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		projectile.pos += projectile.velocity * delta
		projectile.life -= delta
		var consumed: bool = float(projectile.life) <= 0.0
		if not consumed:
			for enemy in enemies:
				var enemy_uid: int = int(enemy.get("uid", 0))
				if enemy_uid in projectile.hit_uids:
					continue
				var enemy_radius: float = enemy.data.radius * ENEMY_COLLISION_SCALE * float(enemy.get("visual_scale", 1.0))
				if projectile.pos.distance_to(enemy.pos) < projectile.radius + enemy_radius:
					enemy.hp -= projectile.damage
					enemy.hit_flash = 0.12
					add_floating_text(("CRIT %d" if bool(projectile.get("critical", false)) else "%d") % int(projectile.damage), enemy.pos, Color("#fff06a") if bool(projectile.get("critical", false)) else Color.WHITE)
					projectile.hit_uids.append(enemy_uid)
					if float(projectile.splash_radius) > 0.0:
						apply_projectile_splash(projectile, enemy_uid)
					projectile.hits_left = int(projectile.hits_left) - 1
					consumed = int(projectile.hits_left) <= 0
					break
		if consumed:
			projectiles.remove_at(index)
			release_projectile(projectile)

func apply_projectile_splash(projectile: Dictionary, direct_hit_uid: int) -> void:
	for enemy in enemies:
		if int(enemy.get("uid", 0)) == direct_hit_uid:
			continue
		if enemy.pos.distance_to(projectile.pos) <= float(projectile.splash_radius):
			enemy.hp -= float(projectile.splash_damage)
			enemy.hit_flash = 0.12

func update_drops(delta: float) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.life -= delta
		if drop.pos.distance_to(player_pos) < 46.0:
			inventory[drop.kind] = int(inventory.get(drop.kind, 0)) + 1
			collected_drops += 1
			score += 12
			progress_objective("collect", String(drop.kind))
			add_floating_text("+%s" % INGREDIENT_LABELS.get(drop.kind, drop.kind), drop.pos, Color("#d8ee7a"))
			drops.remove_at(index)
			AudioManager.play_sfx("raccolta")
		elif drop.life <= 0.0:
			drops.remove_at(index)

func update_trails(delta: float) -> void:
	for index in range(butter_trails.size() - 1, -1, -1):
		var trail: Dictionary = butter_trails[index]
		trail.life -= delta
		var trail_radius := 52.0 if bool(trail.get("strong", false)) else 34.0
		var trail_damage := 22.0 if bool(trail.get("strong", false)) else 12.0
		for enemy in enemies:
			if enemy.pos.distance_to(trail.pos) < trail_radius:
				enemy.hp -= trail_damage * delta
		if trail.life <= 0.0:
			butter_trails.remove_at(index)

func update_deaths(delta: float) -> void:
	for index in range(deaths.size() - 1, -1, -1):
		var death: Dictionary = deaths[index]
		death.time = float(death.time) + delta
		if float(death.time) >= float(death.duration):
			deaths.remove_at(index)

func update_recipe_effects(delta: float) -> void:
	if int(recipe_levels.get("caprese", 0)) > 0:
		caprese_clock += delta
		var abundant_caprese: bool = recipe_evolution_choices.get("caprese", "") == "caprese_abbondante"
		var caprese_interval: float = 1.6 if abundant_caprese else 2.4
		if caprese_clock > caprese_interval:
			var healing: float = 1.15 if abundant_caprese else 0.75
			var healing_cap: float = player_max_health * (CAPRESE_ABUNDANT_HEAL_CAP if abundant_caprese else CAPRESE_HEAL_CAP)
			if player_health < healing_cap:
				player_health = minf(healing_cap, player_health + healing * int(recipe_levels.get("caprese", 0)))
			if recipe_evolution_choices.get("caprese", "") == "caprese_pungente":
				for enemy in enemies:
					if enemy.pos.distance_to(player_pos) < 115.0:
						enemy.hp -= 9.0
						enemy.hit_flash = 0.10
			caprese_clock = 0.0
	if int(recipe_levels.get("tagliatelle", 0)) > 0:
		trail_clock += delta
		var trail_interval := 0.24 if recipe_evolution_choices.get("tagliatelle", "") == "tagliatelle_scia" else 0.35
		if trail_clock > trail_interval:
			butter_trails.append({"pos": player_pos, "life": 3.0 if recipe_evolution_choices.get("tagliatelle", "") == "tagliatelle_scia" else 2.2, "strong": recipe_evolution_choices.get("tagliatelle", "") == "tagliatelle_scia"})
			trail_clock = 0.0
	if int(recipe_levels.get("porchetta", 0)) > 0:
		porchetta_clock += delta
		var porchetta_interval := 0.18 if recipe_evolution_choices.get("porchetta", "") == "porchetta_frenetica" else 0.32
		if porchetta_clock > porchetta_interval:
			var porchetta_range := 135.0 if recipe_evolution_choices.get("porchetta", "") == "porchetta_lunga" else 95.0
			var porchetta_damage := 27.0 if recipe_evolution_choices.get("porchetta", "") == "porchetta_lunga" else 19.0
			for enemy in enemies:
				if enemy.pos.distance_to(player_pos) < porchetta_range:
					enemy.hp -= porchetta_damage * int(recipe_levels.get("porchetta", 0))
					enemy.hit_flash = 0.10
			porchetta_clock = 0.0

func damage_player(amount: float) -> void:
	if player_invulnerable > 0.0:
		return
	player_health -= amount
	player_invulnerable = 0.35
	AudioManager.play_sfx("colpo")

func defeat_enemy(index: int) -> void:
	var enemy: Dictionary = enemies[index]
	kills += 1
	kill_combo = kill_combo + 1 if combo_clock > 0.0 else 1
	combo_clock = 2.4
	update_difficulty_from_kills()
	var base_score: int = 30 + difficulty_tier * 8 if enemy.data.id != "ispettore" else 450
	if "giganti" in active_endless_modifiers:
		base_score *= 2
	score += int(base_score * (1.0 + minf(0.75, kill_combo * 0.05)))
	progress_objective("kill", String(enemy.data.id))
	if kill_combo >= 3:
		add_floating_text("COMBO x%d" % kill_combo, enemy.pos + Vector2(0, -55), Color("#ffd34e"))
	deaths.append({
		"id": String(enemy.data.id),
		"pos": enemy.pos,
		"facing": float(enemy.get("facing", 1.0)),
		"time": 0.0,
		"duration": 0.72,
		"visual_scale": float(enemy.get("visual_scale", 1.0)),
	})
	var count: int = 3 if enemy.data.id == "ispettore" else 1
	if "doppia_dispensa" in active_endless_modifiers:
		count *= 2
	for amount in count:
		var ingredient = enemy.data.drops[rng.randi_range(0, enemy.data.drops.size() - 1)]
		drops.append({"kind": ingredient, "pos": enemy.pos + Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18)), "life": 11.0})
	enemies.remove_at(index)
	release_enemy(enemy)
	AudioManager.play_sfx("sconfitto")

func update_difficulty_from_kills() -> void:
	var new_tier := 0
	for index in range(DIFFICULTY_THRESHOLDS.size()):
		if kills >= int(DIFFICULTY_THRESHOLDS[index]):
			new_tier = index
	if new_tier > difficulty_tier:
		difficulty_tier = new_tier
		score += difficulty_tier * 75

func finish_zone() -> void:
	for enemy in enemies:
		release_enemy(enemy)
	enemies.clear()
	projectiles.clear()
	deaths.clear()
	inspection_zones.clear()
	show_cooking()

func show_cooking() -> void:
	state = GameState.COOKING
	clear_overlay()
	var panel := make_panel(Rect2(40, 205, 640, 790), Color("#293b20"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(30, 26), Vector2(580, 62), 34)
	heading.text = "ULTIMA CUCINA" if zone_index == FINITE_ZONE_COUNT - 1 else "FERMATA IN CUCINA"
	panel.add_child(heading)
	var explanation := make_label(Vector2(44, 88), Vector2(552, 62), 17)
	explanation.text = "Preparati alla Sagra Infinita." if zone_index == FINITE_ZONE_COUNT - 1 else "Scegli una ricetta con la dispensa raccolta."
	panel.add_child(explanation)
	var candidates: Array = []
	for recipe in recipe_catalog:
		if recipe.id not in RunState.completed_recipes:
			candidates.append(recipe)
	candidates.shuffle()
	var candidate_count: int = mini(3, candidates.size())
	for i in range(candidate_count):
		var recipe: RecipeData = candidates[i]
		var card := make_panel(Rect2(36, 170 + i * 175, 568, 146), Color("#3a4f2a"), recipe.accent)
		panel.add_child(card)
		var name := make_label(Vector2(14, 12), Vector2(360, 35), 22, HORIZONTAL_ALIGNMENT_LEFT)
		name.text = recipe.display_name
		card.add_child(name)
		var description := make_label(Vector2(14, 48), Vector2(350, 74), 15, HORIZONTAL_ALIGNMENT_LEFT)
		description.text = recipe.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(description)
		var requirements := make_label(Vector2(14, 113), Vector2(350, 25), 13, HORIZONTAL_ALIGNMENT_LEFT)
		requirements.text = "Serve: " + ingredient_list(recipe.ingredient_ids)
		requirements.add_theme_color_override("font_color", Color("#d9e8bf"))
		card.add_child(requirements)
		var cook := make_button("CUCINA", Rect2(388, 45, 155, 62), 18)
		cook.disabled = not can_cook(recipe)
		cook.pressed.connect(cook_recipe.bind(recipe))
		card.add_child(cook)
	if candidate_count == 0:
		var empty_note := make_label(Vector2(80, 585), Vector2(480, 52), 17)
		empty_note.text = "Nessuna nuova ricetta disponibile."
		panel.add_child(empty_note)
	var continue_text := "ENTRA NELLA SAGRA INFINITA" if zone_index == FINITE_ZONE_COUNT - 1 else "PROSEGUI SENZA CUCINARE"
	var continue_button := make_button(continue_text, Rect2(105, 690, 430, 56), 17)
	continue_button.pressed.connect(skip_cooking)
	panel.add_child(continue_button)

func ingredient_list(ids: Array) -> String:
	var labels: Array[String] = []
	for ingredient in ids:
		labels.append(INGREDIENT_LABELS.get(ingredient, ingredient))
	return ", ".join(labels)

func can_cook(recipe) -> bool:
	for ingredient in recipe.ingredient_ids:
		if int(inventory.get(ingredient, 0)) < 1:
			return false
	return true

func cook_recipe(recipe) -> void:
	if not can_cook(recipe):
		return
	for ingredient in recipe.ingredient_ids:
		inventory[ingredient] = int(inventory[ingredient]) - 1
	recipe_levels[recipe.id] = int(recipe_levels.get(recipe.id, 0)) + 1
	RunState.completed_recipes.append(recipe.id)
	SaveData.unlock_recipe(recipe.id)
	score += 120
	show_recipe_evolution(recipe)

func show_recipe_evolution(recipe: RecipeData) -> void:
	clear_overlay()
	var panel := make_panel(Rect2(52, 300, 616, 650), Color("#293b20"), recipe.accent)
	overlay.add_child(panel)
	var heading := make_label(Vector2(30, 30), Vector2(556, 68), 31)
	heading.text = "EVOLVI: %s" % recipe.display_name.to_upper()
	panel.add_child(heading)
	var note := make_label(Vector2(45, 102), Vector2(526, 55), 17)
	note.text = "Scegli una specialità per questa partita."
	panel.add_child(note)
	var choices: Array = recipe_evolutions.get(recipe.id, [])
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var card := make_panel(Rect2(42, 185 + index * 175, 532, 142), Color("#3a4f2a"), recipe.accent)
		panel.add_child(card)
		var title := make_label(Vector2(18, 12), Vector2(496, 38), 22)
		title.text = String(choice.name)
		card.add_child(title)
		var description := make_label(Vector2(25, 52), Vector2(482, 42), 16)
		description.text = String(choice.description)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(description)
		var select := make_button("SCEGLI", Rect2(165, 96, 202, 40), 17)
		select.pressed.connect(select_recipe_evolution.bind(String(recipe.id), String(choice.id)))
		card.add_child(select)

func select_recipe_evolution(recipe_id: String, evolution_id: String) -> void:
	recipe_evolution_choices[recipe_id] = evolution_id
	score += 180
	advance_to_next_zone()

func skip_cooking() -> void:
	score += 20
	advance_to_next_zone()

func advance_to_next_zone() -> void:
	zone_index += 1
	endless_mode = zone_index >= FINITE_ZONE_COUNT
	zone_remaining = 0.0 if endless_mode else ZONE_DURATION
	inspector_spawned_this_zone = false
	if endless_mode:
		endless_elapsed = 0.0
		endless_score_clock = 0.0
		score += 1000
		next_modifier_wave = 3
	spawn_clock = 1.0
	state = GameState.PLAYING
	clear_overlay()
	setup_zone_objective()
	begin_wave(1)
	AudioManager.play_sfx("cucina")
	update_hud()

func setup_zone_objective() -> void:
	objective_progress = 0
	objective_completed = false
	match zone_index:
		0:
			objective_kind = "collect_any"
			objective_target = 8
		1:
			objective_kind = "kill_ladro"
			objective_target = 8
		2:
			objective_kind = "kill_any"
			objective_target = 18
		3:
			objective_kind = "collect_guanciale"
			objective_target = 6
		4:
			objective_kind = "kill_ispettore"
			objective_target = 1
		_:
			objective_kind = "endless"
			objective_target = 0

func progress_objective(event_kind: String, detail: String) -> void:
	if objective_completed or endless_mode:
		return
	var matches := false
	match objective_kind:
		"collect_any":
			matches = event_kind == "collect"
		"kill_ladro":
			matches = event_kind == "kill" and detail == "ladro"
		"kill_any":
			matches = event_kind == "kill"
		"collect_guanciale":
			matches = event_kind == "collect" and detail == "guanciale"
		"kill_ispettore":
			matches = event_kind == "kill" and detail == "ispettore"
	if not matches:
		return
	objective_progress = mini(objective_target, objective_progress + 1)
	if objective_progress >= objective_target:
		objective_completed = true
		var reward := 350 + zone_index * 100
		score += reward
		player_health = minf(player_max_health, player_health + OBJECTIVE_HEAL)
		add_floating_text("OBIETTIVO! +%d" % reward, player_pos + Vector2(0, -90), Color("#fff06a"))

func objective_text() -> String:
	if endless_mode:
		return "MODIFICATORI: %d  •  SINERGIE: %s" % [active_endless_modifiers.size(), synergy_text()]
	var label := ""
	match objective_kind:
		"collect_any": label = "Raccogli ingredienti"
		"kill_ladro": label = "Ferma i ladri"
		"kill_any": label = "Sconfiggi gli ospiti"
		"collect_guanciale": label = "Raccogli guanciale"
		"kill_ispettore": label = "Supera il controllo"
	if objective_completed:
		return "✓ %s completato" % label
	return "%s: %d/%d" % [label, objective_progress, objective_target]

func synergy_text() -> String:
	var synergies: Array[String] = []
	if int(inventory.get("guanciale", 0)) >= 5:
		synergies.append("RAFFICA")
	if int(inventory.get("olio", 0)) >= 5:
		synergies.append("SCHIZZO")
	return "-" if synergies.is_empty() else "+".join(synergies)

func show_weapon_upgrade_choice() -> void:
	state = GameState.WEAPON_CHOICE
	joystick_touch = -1
	joystick_vector = Vector2.ZERO
	clear_overlay()
	var choices: Array = weapon_upgrade_catalog.duplicate()
	choices.shuffle()
	var panel := make_panel(Rect2(48, 235, 624, 790), Color("#34243d"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(24, 24), Vector2(576, 58), 31)
	heading.text = "LA DISPENSA ISPIRA!"
	panel.add_child(heading)
	var note := make_label(Vector2(38, 82), Vector2(548, 54), 16)
	note.text = "Ogni ricetta e un'arma distinta: potenzia solo il proprio colpo."
	panel.add_child(note)
	for index in range(mini(3, choices.size())):
		var upgrade: Dictionary = choices[index]
		var current_level: int = int(weapon_upgrade_levels.get(String(upgrade.id), 0))
		var card := make_panel(Rect2(34, 148 + index * 184, 556, 158), Color("#4b3153"), Color("#d49a55"))
		panel.add_child(card)
		var title := make_label(Vector2(16, 10), Vector2(524, 36), 21)
		title.text = "%s  %s" % [String(upgrade.name), "NUOVA" if current_level == 0 else "Lv.%d > %d" % [current_level, current_level + 1]]
		card.add_child(title)
		var description := make_label(Vector2(24, 50), Vector2(508, 48), 15)
		description.text = String(upgrade.description)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(description)
		var choose := make_button("PREPARA", Rect2(170, 108, 216, 42), 17)
		choose.pressed.connect(select_weapon_upgrade.bind(String(upgrade.id)))
		card.add_child(choose)

func select_weapon_upgrade(upgrade_id: String) -> void:
	weapon_upgrade_levels[upgrade_id] = int(weapon_upgrade_levels.get(upgrade_id, 0)) + 1
	var total_upgrades := 0
	for level in weapon_upgrade_levels.values():
		total_upgrades += int(level)
	next_weapon_upgrade_at += 5 + total_upgrades * 2
	score += 150
	state = GameState.PLAYING
	clear_overlay()
	add_floating_text("RICETTA POTENZIATA!", player_pos + Vector2(0, -85), Color("#fff06a"))

func show_endless_modifier_choice() -> void:
	next_modifier_wave = endless_wave() + 2
	var available: Array = []
	for modifier in endless_modifier_catalog:
		if String(modifier.id) not in active_endless_modifiers:
			available.append(modifier)
	if available.is_empty():
		score += 500
		add_floating_text("ONDA DOMINATA +500", player_pos, Color("#fff06a"))
		return
	available.shuffle()
	state = GameState.ENDLESS_CHOICE
	clear_overlay()
	var panel := make_panel(Rect2(64, 330, 592, 620), Color("#34243d"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(25, 30), Vector2(542, 70), 32)
	heading.text = "ONDA %d: SCEGLI IL RISCHIO" % endless_wave()
	panel.add_child(heading)
	for index in range(mini(2, available.size())):
		var modifier: Dictionary = available[index]
		var card := make_panel(Rect2(40, 135 + index * 190, 512, 160), Color("#4b3153"), Color("#d49a55"))
		panel.add_child(card)
		var title := make_label(Vector2(16, 10), Vector2(480, 40), 22)
		title.text = String(modifier.name)
		card.add_child(title)
		var description := make_label(Vector2(24, 50), Vector2(464, 55), 16)
		description.text = String(modifier.description)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(description)
		var choose := make_button("ACCETTA", Rect2(155, 110, 202, 42), 17)
		choose.pressed.connect(select_endless_modifier.bind(String(modifier.id)))
		card.add_child(choose)

func select_endless_modifier(modifier_id: String) -> void:
	if modifier_id not in active_endless_modifiers:
		active_endless_modifiers.append(modifier_id)
		for enemy in enemies:
			match modifier_id:
				"doppia_dispensa":
					enemy.speed_scale = float(enemy.speed_scale) * 1.15
				"burro_critico":
					enemy.damage_scale = float(enemy.damage_scale) * 1.20
				"giganti":
					enemy.max_hp = float(enemy.max_hp) * 1.55
					enemy.hp = float(enemy.hp) * 1.55
					enemy.visual_scale = 1.28
	score += 250
	state = GameState.PLAYING
	clear_overlay()

func create_inspection_zone(position: Vector2) -> void:
	inspection_zones.append({"pos": position, "time": 0.0, "triggered": false, "radius": 82.0})

func update_inspection_zones(delta: float) -> void:
	for index in range(inspection_zones.size() - 1, -1, -1):
		var zone: Dictionary = inspection_zones[index]
		zone.time = float(zone.time) + delta
		if float(zone.time) >= 1.05 and not bool(zone.triggered):
			zone.triggered = true
			if player_pos.distance_to(zone.pos) <= float(zone.radius):
				damage_player(18.0)
				add_floating_text("VERBALE!", player_pos, Color("#ff6b57"))
		if float(zone.time) >= 1.55:
			inspection_zones.remove_at(index)

func add_floating_text(value: String, position: Vector2, color: Color) -> void:
	if floating_texts.size() >= 36:
		floating_texts.pop_front()
	floating_texts.append({"text": value, "pos": position, "color": color, "life": 0.85})

func update_floating_texts(delta: float) -> void:
	for index in range(floating_texts.size() - 1, -1, -1):
		var item: Dictionary = floating_texts[index]
		item.life = float(item.life) - delta
		item.pos += Vector2.UP * 34.0 * delta
		if float(item.life) <= 0.0:
			floating_texts.remove_at(index)

func update_butter_rain(delta: float) -> void:
	if "pioggia_burro" not in active_endless_modifiers:
		return
	butter_rain_clock += delta
	if butter_rain_clock < 3.8:
		return
	butter_rain_clock = 0.0
	for index in range(8):
		spawn_food_projectile("burro", Vector2.RIGHT.rotated(TAU * index / 8.0))
	add_floating_text("PIOGGIA DI BURRO!", player_pos + Vector2(0, -70), Color("#fff06a"))

func dash() -> void:
	if state != GameState.PLAYING or elapsed_run < dash_ready_at:
		return
	var direction := joystick_vector
	if direction.length() < 0.1:
		direction = keyboard_direction()
	if direction.length() < 0.1:
		direction = Vector2.UP
	var dash_direction: Vector2 = direction.normalized()
	if absf(dash_direction.x) > 0.05:
		player_facing = signf(dash_direction.x)
	var dash_distance := 165.0 if recipe_evolution_choices.get("tagliatelle", "") == "tagliatelle_sprint" else 120.0
	player_pos += dash_direction * dash_distance
	world_camera.position = player_pos
	player_invulnerable = 0.45
	dash_ready_at = elapsed_run + 2.8
	AudioManager.play_sfx("scatto")

func show_dinner() -> void:
	state = GameState.DINNER
	clear_overlay()
	var ingredient_value: int = 0
	for ingredient in inventory:
		ingredient_value += int(inventory[ingredient]) * (6 if ingredient != "vino" else 15)
	var recipe_value: int = RunState.completed_recipes.size() * 260 + recipe_evolution_choices.size() * 150
	var freshness: int = int(player_health * 3.0)
	var wine_pairing: int = int(inventory.get("vino", 0)) * 35
	score += ingredient_value + recipe_value + freshness + wine_pairing
	RunState.score = score
	if not score_recorded:
		was_new_best = SaveData.record_run(score, kills, mini(zone_index, FINITE_ZONE_COUNT), int(endless_elapsed))
		submit_online_run()
		score_recorded = true
	var panel := make_panel(Rect2(42, 220, 636, 760), Color("#38291d"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(24, 34), Vector2(588, 62), 38)
	heading.text = "È ORA DI CENA!"
	heading.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(heading)
	var text := make_label(Vector2(66, 135), Vector2(504, 330), 22, HORIZONTAL_ALIGNMENT_LEFT)
	text.text = "Nemici superati          %d\nQualità delle ricette  +%d\nFreschezza               +%d\nAbbinamento vino       +%d\nDispensa rimasta       +%d\n\nTOTALE                    %d" % [kills, recipe_value, freshness, wine_pairing, ingredient_value, score]
	text.add_theme_color_override("font_color", Color("#fff4d6"))
	panel.add_child(text)
	var verdict := make_label(Vector2(65, 505), Vector2(506, 58), 20)
	verdict.text = "NUOVO RECORD!" if was_new_best else "Gli ospiti chiedono il bis."
	verdict.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(verdict)
	var again := make_button("UN'ALTRA SAGRA", Rect2(38, 610, 270, 70), 20)
	again.pressed.connect(start_run)
	panel.add_child(again)
	var ranking := make_button("CLASSIFICA", Rect2(328, 610, 270, 70), 20)
	ranking.pressed.connect(show_leaderboard)
	panel.add_child(ranking)

func show_game_over() -> void:
	state = GameState.GAME_OVER
	RunState.score = score
	if not score_recorded:
		was_new_best = SaveData.record_run(score, kills, mini(zone_index, FINITE_ZONE_COUNT), int(endless_elapsed))
		submit_online_run()
		score_recorded = true
	clear_overlay()
	var panel := make_panel(Rect2(66, 340, 588, 520), Color("#3e261d"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(28, 42), Vector2(532, 70), 36)
	heading.text = "PADELLA VUOTA!"
	panel.add_child(heading)
	var message := make_label(Vector2(42, 135), Vector2(504, 90), 20)
	message.text = "La fame ha avuto la meglio.\nPunti: %d   Nemici: %d\n%s" % [score, kills, "Nuovo record!" if was_new_best else "Risultato salvato in classifica."]
	panel.add_child(message)
	var retry := make_button("RIPROVA", Rect2(42, 320, 238, 72), 22)
	retry.pressed.connect(start_run)
	panel.add_child(retry)
	var ranking := make_button("CLASSIFICA", Rect2(308, 320, 238, 72), 19)
	ranking.pressed.connect(show_leaderboard)
	panel.add_child(ranking)

func toggle_pause() -> void:
	if state == GameState.PLAYING:
		show_pause()
	elif state == GameState.PAUSED:
		resume_game()

func submit_online_run() -> void:
	if OnlineLeaderboard.has_identity():
		OnlineLeaderboard.submit_score(score, kills, mini(zone_index, FINITE_ZONE_COUNT), int(endless_elapsed))

func show_pause() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	joystick_touch = -1
	joystick_vector = Vector2.ZERO
	clear_overlay()
	var panel_height := 480.0 if endless_mode else 390.0
	var panel := make_panel(Rect2(130, 385, 460, panel_height), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(20, 35), Vector2(420, 56), 32)
	heading.text = "PAUSA"
	panel.add_child(heading)
	var resume := make_button("TORNA ALLA SAGRA", Rect2(65, 120, 330, 66), 20)
	resume.pressed.connect(resume_game)
	panel.add_child(resume)
	var next_y := 210.0
	if endless_mode:
		var dinner := make_button("SERVI LA CENA", Rect2(65, next_y, 330, 66), 20)
		dinner.pressed.connect(show_dinner)
		panel.add_child(dinner)
		next_y += 90.0
	var quit := make_button("TORNA AL MENU", Rect2(65, next_y, 330, 66), 19)
	quit.pressed.connect(show_menu)
	panel.add_child(quit)

func resume_game() -> void:
	state = GameState.PLAYING
	clear_overlay()

func update_hud() -> void:
	if state != GameState.PLAYING:
		return
	if endless_mode:
		hud_labels.zone.text = "INFINITA - ONDA %d%s" % [endless_wave(), " SPECIALE" if wave_is_special else ""]
		var infinite_seconds := int(endless_elapsed)
		hud_labels.timer.text = "%02d:%02d" % [floori(infinite_seconds / 60.0), infinite_seconds % 60]
	else:
		hud_labels.zone.text = "%d/%d %s - ONDA %d/%d" % [zone_index + 1, FINITE_ZONE_COUNT, ZONES[zone_index], wave_number, WAVES_PER_ZONE]
		var remaining_seconds := int(maxf(0.0, zone_remaining))
		hud_labels.timer.text = "%02d:%02d" % [floori(remaining_seconds / 60.0), remaining_seconds % 60]
	hud_labels.health.text = "VITA %d / %d" % [int(player_health), int(player_max_health)]
	hud_labels.score.text = "PUNTI %d - KO %d%s" % [score, kills, " x%d" % kill_combo if kill_combo >= 3 else ""]
	var wave_status := "ONDA"
	if not wave_active:
		wave_status = "RESPIRO %ds" % ceili(wave_break_remaining)
	elif wave_is_special:
		wave_status = "SPECIALISTA"
	hud_labels.objective.text = "[%s] %s" % [wave_status, objective_text()]
	var compact := ""
	for key in ["guanciale", "olio"]:
		compact += "%s:%d  " % [INGREDIENT_LABELS[key].left(3), int(inventory.get(key, 0))]
	compact += "UPG:%d/%d" % [collected_drops, next_weapon_upgrade_at]
	hud_labels.pantry.text = compact.strip_edges()
	dash_button.text = "SCATTO" if elapsed_run >= dash_ready_at else "ATTENDI"

func _draw() -> void:
	draw_pixel_background()
	for zone in inspection_zones:
		var warning_progress: float = clampf(float(zone.time) / 1.05, 0.0, 1.0)
		var zone_color := Color(0.92, 0.20, 0.14, 0.12 + warning_progress * 0.20)
		draw_circle(zone.pos, float(zone.radius), zone_color)
		draw_arc(zone.pos, float(zone.radius), 0.0, TAU, 36, Color(1.0, 0.76, 0.28, 0.55 + warning_progress * 0.35), 4.0)
	for trail in butter_trails:
		draw_circle(trail.pos, 27.0 if bool(trail.get("strong", false)) else 18.0, Color(1.0, 0.85, 0.35, 0.42))
	for death in deaths:
		draw_enemy_death(death)
	for drop in drops:
		draw_ingredient_drop(drop)
	for projectile in projectiles:
		draw_food_projectile(projectile)
	for enemy in enemies:
		draw_enemy(enemy)
	draw_player()
	for item in floating_texts:
		var text_color: Color = item.color
		text_color.a = clampf(float(item.life) / 0.35, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, item.pos, String(item.text), HORIZONTAL_ALIGNMENT_CENTER, 140, 18, text_color)
	if state == GameState.PLAYING:
		draw_virtual_joystick()

func get_camera_center() -> Vector2:
	if world_camera != null:
		return world_camera.get_screen_center_position()
	return player_pos

func draw_pixel_background() -> void:
	var center: Vector2 = get_camera_center()
	var padding := Vector2(WORLD_TILE_SIZE, WORLD_TILE_SIZE)
	var visible_rect := Rect2(center - Vector2(W, H) * 0.5 - padding, Vector2(W, H) + padding * 2.0)
	var min_grid_x: int = floori(visible_rect.position.x / WORLD_TILE_SIZE)
	var max_grid_x: int = ceili(visible_rect.end.x / WORLD_TILE_SIZE)
	var min_grid_y: int = floori(visible_rect.position.y / WORLD_TILE_SIZE)
	var max_grid_y: int = ceili(visible_rect.end.y / WORLD_TILE_SIZE)
	for grid_y in range(min_grid_y, max_grid_y + 1):
		for grid_x in range(min_grid_x, max_grid_x + 1):
			draw_world_tile(grid_x, grid_y)

func draw_world_tile(grid_x: int, grid_y: int) -> void:
	var origin := Vector2(grid_x * WORLD_TILE_SIZE, grid_y * WORLD_TILE_SIZE)
	var variation: int = absi(grid_x * 37 + grid_y * 61 + zone_index * 17) % 11
	var base: Color = ZONE_COLORS[zone_index]
	var tile_color: Color = base.lightened(0.035) if variation % 2 == 0 else base.darkened(0.025)
	draw_rect(Rect2(origin, Vector2.ONE * WORLD_TILE_SIZE), tile_color)
	draw_rect(Rect2(origin, Vector2(WORLD_TILE_SIZE, 3)), tile_color.lightened(0.08))
	draw_rect(Rect2(origin + Vector2(0, WORLD_TILE_SIZE - 3), Vector2(WORLD_TILE_SIZE, 3)), tile_color.darkened(0.10))
	match zone_index:
		0:
			draw_orto_tile(origin, variation)
		1:
			draw_bosco_tile(origin, variation)
		2:
			draw_vigneto_tile(origin, variation, grid_x)
		3:
			draw_fattoria_tile(origin, variation, grid_x, grid_y)
		4:
			draw_piazza_tile(origin, variation, grid_x, grid_y)
		_:
			draw_infinite_tile(origin, variation, grid_x, grid_y)

func draw_orto_tile(origin: Vector2, variation: int) -> void:
	if variation in [0, 3, 6, 9]:
		for row in range(3):
			var crop_pos := origin + Vector2(12 + row * 18, 22 + (variation % 2) * 8)
			draw_rect(Rect2(crop_pos, Vector2(5, 16)), Color("#315d2c"))
			draw_rect(Rect2(crop_pos + Vector2(-5, 1), Vector2(6, 6)), Color("#6ea43c"))
			draw_rect(Rect2(crop_pos + Vector2(4, -3), Vector2(7, 7)), Color("#91bd4f"))
	elif variation == 5:
		draw_rect(Rect2(origin + Vector2(19, 28), Vector2(20, 6)), Color("#b67a35"))
		draw_rect(Rect2(origin + Vector2(27, 19), Vector2(6, 20)), Color("#d8a44c"))
	else:
		draw_rect(Rect2(origin + Vector2(9 + variation * 3, 39), Vector2(5, 10)), Color("#4e7b32"))

func draw_bosco_tile(origin: Vector2, variation: int) -> void:
	if variation in [1, 5, 8]:
		draw_rect(Rect2(origin + Vector2(11, 12), Vector2(30, 34)), Color("#38552f"))
		draw_rect(Rect2(origin + Vector2(18, 4), Vector2(22, 15)), Color("#456b36"))
		draw_rect(Rect2(origin + Vector2(25, 38), Vector2(9, 18)), Color("#5e3b24"))
	elif variation in [3, 9]:
		draw_rect(Rect2(origin + Vector2(18, 36), Vector2(6, 12)), Color("#f1d49a"))
		draw_rect(Rect2(origin + Vector2(11, 29), Vector2(20, 9)), Color("#b55435"))
		draw_rect(Rect2(origin + Vector2(42, 45), Vector2(5, 9)), Color("#ead39d"))
		draw_rect(Rect2(origin + Vector2(37, 39), Vector2(15, 7)), Color("#dbb64a"))
	else:
		draw_rect(Rect2(origin + Vector2(12 + variation * 2, 20), Vector2(4, 18)), Color("#668748"))

func draw_vigneto_tile(origin: Vector2, variation: int, grid_x: int) -> void:
	if grid_x % 3 == 0:
		draw_rect(Rect2(origin + Vector2(9, 0), Vector2(7, WORLD_TILE_SIZE)), Color("#493323"))
		draw_rect(Rect2(origin + Vector2(16, 25), Vector2(34, 6)), Color("#38542c"))
		draw_rect(Rect2(origin + Vector2(23, 16), Vector2(10, 10)), Color("#668c3b"))
		draw_rect(Rect2(origin + Vector2(38, 31), Vector2(9, 9)), Color("#6f314f"))
	elif variation in [2, 7]:
		draw_rect(Rect2(origin + Vector2(22, 17), Vector2(17, 24)), Color("#8d6340"))
		draw_rect(Rect2(origin + Vector2(18, 14), Vector2(25, 7)), Color("#b5844f"))
	else:
		draw_rect(Rect2(origin + Vector2(15 + variation, 43), Vector2(12, 5)), Color("#93613b"))

func draw_fattoria_tile(origin: Vector2, variation: int, grid_x: int, grid_y: int) -> void:
	if (grid_x + grid_y) % 5 == 0:
		draw_rect(Rect2(origin + Vector2(8, 13), Vector2(48, 8)), Color("#6e4325"))
		draw_rect(Rect2(origin + Vector2(12, 35), Vector2(44, 7)), Color("#7f512d"))
		for post_x in [12, 48]:
			draw_rect(Rect2(origin + Vector2(post_x, 8), Vector2(6, 46)), Color("#4f321f"))
	elif variation in [2, 7]:
		draw_rect(Rect2(origin + Vector2(18, 32), Vector2(29, 18)), Color("#d6a745"))
		draw_rect(Rect2(origin + Vector2(22, 26), Vector2(21, 8)), Color("#edc55e"))
	else:
		draw_rect(Rect2(origin + Vector2(12, 46), Vector2(42, 4)), Color("#74502e"))

func draw_piazza_tile(origin: Vector2, variation: int, grid_x: int, grid_y: int) -> void:
	var stone := Color("#d19a63") if (grid_x + grid_y) % 2 == 0 else Color("#b97c50")
	draw_rect(Rect2(origin + Vector2(4, 4), Vector2(56, 56)), stone)
	draw_rect(Rect2(origin + Vector2(4, 4), Vector2(56, 4)), stone.lightened(0.12))
	if variation in [1, 6]:
		for flag in range(3):
			var flag_color: Color = [Color("#3f7e49"), Color("#f3e4bd"), Color("#b94b3c")][flag]
			draw_colored_polygon(PackedVector2Array([
				origin + Vector2(10 + flag * 18, 12), origin + Vector2(23 + flag * 18, 12),
				origin + Vector2(16 + flag * 18, 24),
			]), flag_color)
	elif variation == 9:
		draw_circle(origin + Vector2(32, 32), 11.0, Color("#6d8f9e"))
		draw_circle(origin + Vector2(32, 32), 5.0, Color("#bde2e5"))

func draw_infinite_tile(origin: Vector2, variation: int, grid_x: int, grid_y: int) -> void:
	if (grid_x + grid_y) % 4 == 0:
		draw_circle(origin + Vector2(32, 32), 18.0, Color("#693a58"))
		draw_circle(origin + Vector2(32, 32), 9.0, Color("#d49a55"))
	elif variation in [3, 8]:
		draw_colored_polygon(PackedVector2Array([
			origin + Vector2(10, 18), origin + Vector2(54, 18), origin + Vector2(44, 28),
			origin + Vector2(20, 28),
		]), Color("#d3b765"))
	else:
		draw_rect(Rect2(origin + Vector2(11, 40), Vector2(42, 5)), Color("#704a5d"))

func draw_player() -> void:
	if int(recipe_levels.get("caprese", 0)) > 0:
		draw_arc(player_pos, 47.0, 0.0, TAU, 24, Color(0.36, 0.92, 0.36, 0.38), 4.0)
	if int(recipe_levels.get("porchetta", 0)) > 0:
		var blade := player_pos + Vector2(72, 0).rotated(elapsed_run * 5.0)
		draw_circle(blade, 23.0, Color("#9e3d1e"))
		draw_circle(blade, 15.0, Color("#efad56"))
	var texture := CHEF_IDLE_TEXTURE
	var walk_phase: float = elapsed_run * WALK_ANIMATION_FPS
	var frame := floori(walk_phase) % CHEF_ANIMATION_FRAMES if player_is_moving else 0
	# Keep locomotion readable while moving; show the full throw animation when stationary.
	if attack_animation_time > 0.0 and not player_is_moving:
		texture = CHEF_ATTACK_TEXTURE
		var attack_progress := 1.0 - attack_animation_time / CHEF_ATTACK_DURATION
		frame = clampi(floori(attack_progress * float(CHEF_ANIMATION_FRAMES)), 0, CHEF_ANIMATION_FRAMES - 1)
	var source := Rect2(Vector2(frame * 128, 0), CHEF_FRAME_SIZE)
	var destination := Rect2(
		Vector2(-CHEF_DRAW_SIZE * 0.5, -CHEF_DRAW_SIZE * 0.75),
		Vector2.ONE * CHEF_DRAW_SIZE,
	)
	var modulation := Color.WHITE
	if player_invulnerable > 0.0 and int(player_invulnerable * 20.0) % 2 == 0:
		modulation.a = 0.45
	var walk_cycle: float = walk_phase / float(CHEF_ANIMATION_FRAMES) * TAU
	var walk_bob := -absf(sin(walk_cycle)) * 3.5 if player_is_moving else 0.0
	var walk_lean := sin(walk_cycle) * 0.025 if player_is_moving else 0.0
	draw_set_transform(player_pos + Vector2(0, walk_bob), walk_lean * player_facing, Vector2(player_facing, 1.0))
	draw_texture_rect_region(texture, destination, source, modulation)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_food_projectile(projectile: Dictionary) -> void:
	var radius: float = float(projectile.radius)
	var frame: int = (floori(elapsed_run * 14.0) + int(projectile.get("spin_offset", 0))) % 4
	var kind: String = String(projectile.get("kind", "burro"))
	var texture: Texture2D = BUTTER_PROJECTILE_TEXTURE
	var draw_size: float = clampf(44.0 + radius * 1.45, 56.0, 82.0)
	match kind:
		"vitello_tonnato":
			texture = VITELLO_PROJECTILE_TEXTURE
			draw_size = clampf(48.0 + radius * 1.35, 68.0, 94.0)
		"uova_purgatorio":
			texture = UOVA_PROJECTILE_TEXTURE
			draw_size = clampf(48.0 + radius * 1.30, 66.0, 92.0)
		"spaghetti_aglione":
			texture = SPAGHETTI_PROJECTILE_TEXTURE
			draw_size = clampf(46.0 + radius * 1.25, 62.0, 86.0)
		"kegiorg":
			texture = KEGIORG_PROJECTILE_TEXTURE
			draw_size = clampf(50.0 + radius * 1.35, 70.0, 98.0)
	var source: Rect2 = Rect2(Vector2(frame * 64, 0), Vector2(64, 64))
	var destination: Rect2 = Rect2(projectile.pos - Vector2.ONE * draw_size * 0.5, Vector2.ONE * draw_size)
	draw_circle(projectile.pos + Vector2(4, 6), radius + 3.0, Color(0.15, 0.08, 0.04, 0.24))
	draw_texture_rect_region(texture, destination, source)

func draw_ingredient_drop(drop: Dictionary) -> void:
	var kind: String = String(drop.kind)
	if kind not in ["guanciale", "olio"]:
		draw_circle(drop.pos, 12.0, Color("#fff4d6"))
		draw_circle(drop.pos, 8.0, INGREDIENT_COLORS.get(kind, Color.WHITE))
		return
	var texture: Texture2D = DROP_GUANCIALE_TEXTURE if kind == "guanciale" else DROP_OLIO_TEXTURE
	var position: Vector2 = drop.pos
	var bounce: float = sin(float(drop.life) * 5.0) * 3.0
	var size := Vector2(52, 52)
	draw_ellipse_shadow(position + Vector2(0, 18), 15.0)
	draw_texture_rect(texture, Rect2(position - Vector2(26, 29 - bounce), size), false)

func draw_ellipse_shadow(position: Vector2, radius: float) -> void:
	draw_set_transform(position, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius, Color(0.12, 0.07, 0.03, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_enemy_death(death: Dictionary) -> void:
	var enemy_id: String = String(death.id)
	if enemy_id == "oca":
		draw_oca_death(death)
		return
	if enemy_id == "cinghiale":
		draw_cinghiale_death(death)
		return
	var texture: Texture2D = ENEMY_TURISTA_DEATH_TEXTURE
	var draw_size: float = 108.0
	match enemy_id:
		"ispettore":
			texture = ENEMY_ISPETTORE_DEATH_TEXTURE
			draw_size = 158.0
		"ladro":
			texture = ENEMY_LADRO_DEATH_TEXTURE
			draw_size = 128.0
		"turista":
			draw_size = 124.0
	draw_size *= float(death.get("visual_scale", 1.0))
	var progress: float = clampf(float(death.time) / float(death.duration), 0.0, 0.999)
	var frame: int = clampi(floori(progress * float(ENEMY_ANIMATION_FRAMES)), 0, ENEMY_ANIMATION_FRAMES - 1)
	var source := Rect2(Vector2(frame * 128, 0), CHEF_FRAME_SIZE)
	var position: Vector2 = death.pos
	var destination := Rect2(position - Vector2(draw_size * 0.5, draw_size * 0.72), Vector2.ONE * draw_size)
	var modulation := Color(1.0, 1.0, 1.0, 1.0 - progress * 0.35)
	var facing: float = float(death.get("facing", 1.0))
	destination.position -= position
	draw_set_transform(position, 0.0, Vector2(facing, 1.0))
	draw_texture_rect_region(texture, destination, source, modulation)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_enemy(enemy) -> void:
	var pos: Vector2 = enemy.pos
	var color: Color = enemy.data.accent
	var facing: float = float(enemy.get("facing", 1.0))
	if enemy.data.id in ["ispettore", "turista", "ladro"]:
		draw_human_enemy(enemy)
		return
	if enemy.data.id == "oca":
		draw_oca_enemy(enemy)
		return
	elif enemy.data.id == "cinghiale":
		draw_circle(pos, enemy.data.radius, color)
		draw_circle(pos + Vector2(17 * facing, -3), 12, color.lightened(0.12))
		draw_line(pos + Vector2(21 * facing, 6), pos + Vector2(33 * facing, 11), Color("#f4e8c3"), 4)
	elif enemy.data.id == "ispettore":
		draw_circle(pos, enemy.data.radius, color)
		draw_rect(Rect2(pos + Vector2(-25, -14), Vector2(50, 32)), Color("#f4f0dc"))
		draw_rect(Rect2(pos + Vector2(-30, -33), Vector2(60, 12)), Color("#4e5d65"))
	else:
		draw_circle(pos, enemy.data.radius, color)
		draw_rect(Rect2(pos + Vector2(-11, -5), Vector2(22, 23)), color.darkened(0.22))
	if enemy.hit_flash > 0.0:
		draw_arc(pos, enemy.data.radius + 5.0, 0.0, TAU, 12, Color.WHITE, 2.0)

func draw_oca_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy.pos
	var facing: float = float(enemy.get("facing", 1.0))
	var phase: float = elapsed_run * 9.0 + float(int(enemy.get("uid", 0)) % 7)
	var bob := sin(phase) * 3.0
	var foot_step := sin(phase) * 5.0
	var body_pos := pos + Vector2(0, bob)
	var body_color := Color("#fff7df")
	if enemy.hit_flash > 0.0:
		body_color = Color("#ff9a8d")
	draw_ellipse_shadow(pos + Vector2(0, 22), 24.0)
	draw_circle(body_pos, 29.0, body_color)
	draw_circle(body_pos + Vector2(22 * facing, -23), 14.0, body_color)
	draw_line(body_pos + Vector2(7 * facing, -2), body_pos + Vector2(21 * facing, -22), body_color, 14.0)
	var wing_y := 2.0 + absf(sin(phase)) * 7.0
	draw_colored_polygon(PackedVector2Array([
		body_pos + Vector2(-19 * facing, -7),
		body_pos + Vector2(7 * facing, wing_y),
		body_pos + Vector2(-17 * facing, 12),
	]), Color("#e4ddca"))
	draw_colored_polygon(PackedVector2Array([
		body_pos + Vector2(32 * facing, -26),
		body_pos + Vector2(48 * facing, -20),
		body_pos + Vector2(32 * facing, -14),
	]), Color("#e8a534"))
	draw_circle(body_pos + Vector2(27 * facing, -27), 2.5, Color("#241811"))
	draw_line(body_pos + Vector2(-8, 23), body_pos + Vector2(-10 + foot_step, 34), Color("#d89527"), 4.0)
	draw_line(body_pos + Vector2(9, 23), body_pos + Vector2(11 - foot_step, 34), Color("#d89527"), 4.0)
	if enemy.hit_flash > 0.0:
		draw_arc(pos, enemy.data.radius + 5.0, 0.0, TAU, 12, Color.WHITE, 2.0)

func draw_oca_death(death: Dictionary) -> void:
	var progress: float = clampf(float(death.time) / float(death.duration), 0.0, 1.0)
	var alpha := 1.0 - progress * 0.55
	var white := Color("#fff7df")
	var beak := Color("#e8a534")
	white.a = alpha
	beak.a = alpha
	var facing: float = float(death.get("facing", 1.0))
	var position: Vector2 = death.pos + Vector2(0, progress * 24.0)
	draw_set_transform(position, facing * progress * 1.2, Vector2(facing, 1.0))
	draw_circle(Vector2.ZERO, 29.0 * (1.0 - progress * 0.18), white)
	draw_circle(Vector2(22, -23), 14.0, white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(32, -26), Vector2(48, -20), Vector2(32, -14),
	]), beak)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_cinghiale_death(death: Dictionary) -> void:
	var progress: float = clampf(float(death.time) / float(death.duration), 0.0, 1.0)
	var body := Color("#4a281d")
	body.a = 1.0 - progress * 0.55
	var facing: float = float(death.get("facing", 1.0))
	var position: Vector2 = death.pos + Vector2(0, progress * 20.0)
	draw_set_transform(position, facing * progress * 0.9, Vector2(facing, 1.0))
	draw_circle(Vector2.ZERO, 30.0 * (1.0 - progress * 0.15), body)
	draw_circle(Vector2(22, -3), 14.0, body.lightened(0.12))
	draw_line(Vector2(24, 6), Vector2(36, 12), Color(0.95, 0.90, 0.75, body.a), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_human_enemy(enemy: Dictionary) -> void:
	var texture: Texture2D = ENEMY_TURISTA_TEXTURE
	var draw_size: float = 124.0
	match String(enemy.data.id):
		"ispettore":
			texture = ENEMY_ISPETTORE_TEXTURE
			draw_size = 158.0
		"ladro":
			texture = ENEMY_LADRO_TEXTURE
			draw_size = 128.0
	draw_size *= float(enemy.get("visual_scale", 1.0))
	var phase: float = elapsed_run * WALK_ANIMATION_FPS + float(int(enemy.get("uid", 0)) % ENEMY_ANIMATION_FRAMES) * 0.65
	var frame: int = floori(phase) % ENEMY_ANIMATION_FRAMES
	var source: Rect2 = Rect2(Vector2(frame * 128, 0), CHEF_FRAME_SIZE)
	var size: Vector2 = Vector2(draw_size, draw_size)
	var destination: Rect2 = Rect2(enemy.pos - Vector2(draw_size * 0.5, draw_size * 0.72), size)
	var modulation: Color = Color.WHITE
	if enemy.hit_flash > 0.0:
		modulation = Color(1.0, 0.58, 0.58, 1.0)
	var facing: float = float(enemy.get("facing", 1.0))
	var walk_cycle: float = phase / float(ENEMY_ANIMATION_FRAMES) * TAU
	var walk_bob := -absf(sin(walk_cycle)) * 3.0
	var walk_lean := sin(walk_cycle) * 0.022
	destination.position -= enemy.pos
	draw_set_transform(enemy.pos + Vector2(0, walk_bob), walk_lean * facing, Vector2(facing, 1.0))
	draw_texture_rect_region(texture, destination, source, modulation)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if String(enemy.data.id) == "ispettore":
		var health_ratio: float = clampf(float(enemy.hp) / maxf(1.0, float(enemy.get("max_hp", enemy.data.max_health))), 0.0, 1.0)
		var bar_position: Vector2 = enemy.pos + Vector2(-58, -112)
		draw_rect(Rect2(bar_position, Vector2(116, 12)), Color("#33231d"))
		draw_rect(Rect2(bar_position + Vector2(2, 2), Vector2(112 * health_ratio, 8)), Color("#d34d39"))
		draw_rect(Rect2(enemy.pos + Vector2(-58, -135), Vector2(116, 19)), Color("#f4f0dc"))
		draw_string(ThemeDB.fallback_font, enemy.pos + Vector2(-53, -120), String(enemy.get("role_title", "DIETOLOGO")), HORIZONTAL_ALIGNMENT_CENTER, 106, 13, Color("#33231d"))
	if enemy.hit_flash > 0.0:
		draw_arc(enemy.pos, enemy.data.radius + 5.0, 0.0, TAU, 12, Color.WHITE, 2.0)

func draw_virtual_joystick() -> void:
	var screen_origin: Vector2 = get_camera_center() - Vector2(W, H) * 0.5
	var world_center: Vector2 = screen_origin + joystick_center
	draw_circle(world_center, 74.0, Color(0.12, 0.18, 0.1, 0.24))
	draw_arc(world_center, 74.0, 0.0, TAU, 28, Color(1.0, 0.95, 0.75, 0.45), 3.0)
	draw_circle(world_center + joystick_vector * 45.0, 30.0, Color(0.96, 0.78, 0.33, 0.58))
