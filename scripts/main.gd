extends Node2D

## A compact, self-contained vertical slice. Visuals are deliberately drawn with
## chunky primitives so the project runs before a texture atlas is imported.

enum GameState { MENU, PLAYING, COOKING, DINNER, GAME_OVER, PAUSED }

const W := 720.0
const H := 1280.0
const PLAY_TOP := 132.0
const PLAY_BOTTOM := 1055.0
const WORLD_TILE_SIZE := 64.0
const ZONE_DURATION := 150.0
const CHEF_IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/chef_walk_v3.png")
const CHEF_ATTACK_TEXTURE: Texture2D = preload("res://assets/sprites/chef_attack_butter_v2.png")
const BUTTER_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/sprites/butter_projectile_v1.png")
const ENEMY_ISPETTORE_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ispettore_walk_v3.png")
const ENEMY_TURISTA_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_turista_walk_v3.png")
const ENEMY_LADRO_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ladro_walk_v3.png")
const ENEMY_ISPETTORE_DEATH_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ispettore_death_v2.png")
const ENEMY_TURISTA_DEATH_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_turista_death_v2.png")
const ENEMY_LADRO_DEATH_TEXTURE: Texture2D = preload("res://assets/sprites/enemy_ladro_death_v2.png")
const ENEMY_ANIMATION_FRAMES := 8
const DROP_GUANCIALE_TEXTURE: Texture2D = preload("res://assets/sprites/drop_guanciale_v1.png")
const DROP_OLIO_TEXTURE: Texture2D = preload("res://assets/sprites/drop_olio_v1.png")
const CHEF_FRAME_SIZE := Vector2(128, 128)
const CHEF_ANIMATION_FRAMES := 8
const CHEF_DRAW_SIZE := 124.0
const CHEF_ATTACK_DURATION := 0.48
const ZONES := ["L'Orto", "Bosco dei Funghi", "Vigneto"]
const ZONE_COLORS := [Color("#78933a"), Color("#4f7044"), Color("#7a4b3a")]
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
	preload("res://data/enemies/cinghiale.tres"), preload("res://data/enemies/oca.tres"),
	preload("res://data/enemies/turista.tres"), preload("res://data/enemies/ladro.tres"),
	preload("res://data/enemies/ispettore.tres"),
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
var attack_clock := 0.0
var attack_animation_time := 0.0
var caprese_clock := 0.0
var porchetta_clock := 0.0
var trail_clock := 0.0
var dash_ready_at := 0.0
var elapsed_run := 0.0
var score := 0
var recipe_levels := {}
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

func _ready() -> void:
	rng.randomize()
	world_camera = Camera2D.new()
	world_camera.position = player_pos
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 7.0
	add_child(world_camera)
	world_camera.make_current()
	build_interface()
	show_menu()
	queue_redraw()

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		update_play(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
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
	layer.add_child(overlay)

	var top := make_panel(Rect2(12, 12, 696, 106), Color("#24321d"), Color("#f3d47c"))
	hud.add_child(top)
	hud_labels.zone = make_label(Vector2(28, 19), Vector2(320, 34), 25, HORIZONTAL_ALIGNMENT_LEFT)
	hud_labels.timer = make_label(Vector2(365, 19), Vector2(180, 34), 25, HORIZONTAL_ALIGNMENT_RIGHT)
	hud_labels.health = make_label(Vector2(28, 54), Vector2(210, 34), 21, HORIZONTAL_ALIGNMENT_LEFT)
	hud_labels.score = make_label(Vector2(250, 54), Vector2(150, 34), 21, HORIZONTAL_ALIGNMENT_CENTER)
	hud_labels.pantry = make_label(Vector2(410, 51), Vector2(275, 42), 16, HORIZONTAL_ALIGNMENT_RIGHT)
	for label in hud_labels.values():
		top.add_child(label)

	var pause := make_button("Ⅱ", Rect2(645, 22, 52, 42), 24)
	pause.pressed.connect(show_pause)
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
	hud.visible = false
	clear_overlay()
	var panel := make_panel(Rect2(48, 250, 624, 680), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var title := make_label(Vector2(28, 42), Vector2(568, 122), 52)
	title.text = "GIORGIONE'S\nFEAST"
	title.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(title)
	var subtitle := make_label(Vector2(52, 184), Vector2(520, 100), 23)
	subtitle.text = "Raccogli, cucina, servi.\nPrima che arrivi la fame."
	panel.add_child(subtitle)
	var start := make_button("INIZIA LA SAGRA", Rect2(78, 325, 468, 74), 25)
	start.pressed.connect(start_run)
	panel.add_child(start)
	var best := make_label(Vector2(58, 430), Vector2(508, 45), 19)
	best.text = "Miglior cena: %d punti" % int(SaveData.data.best_score)
	panel.add_child(best)
	var note := make_label(Vector2(48, 525), Vector2(528, 84), 14)
	note.text = "Opera fan non ufficiale.\nTocca e trascina a sinistra per muoverti."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#d4e0bd"))
	panel.add_child(note)

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
	recipe_levels.clear()
	for key in INGREDIENT_LABELS:
		inventory[key] = 1
	enemies.clear()
	projectiles.clear()
	drops.clear()
	deaths.clear()
	butter_trails.clear()
	was_new_best = false
	AudioManager.play_music("campagna")
	update_hud()

func update_play(delta: float) -> void:
	elapsed_run += delta
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
		player_pos += movement_direction * player_speed * speed_multiplier * delta
	world_camera.position = player_pos
	spawn_clock -= delta
	if spawn_clock <= 0.0:
		spawn_enemy()
		spawn_clock = maxf(0.46, 1.3 - elapsed_run / 260.0)
	attack_clock -= delta
	if attack_clock <= 0.0:
		auto_attack()
		attack_clock = maxf(0.26, 0.68 - 0.08 * int(recipe_levels.get("polenta", 0)))
	update_recipe_effects(delta)
	update_enemies(delta)
	update_projectiles(delta)
	update_drops(delta)
	update_trails(delta)
	update_deaths(delta)
	if player_health <= 0.0:
		show_game_over()
	elif zone_remaining <= 0.0:
		finish_zone()
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
	if zone_index == 0:
		options = [enemy_catalog[2], enemy_catalog[3]]
	elif zone_index == 1:
		options = [enemy_catalog[3], enemy_catalog[2]]
	else:
		options = [enemy_catalog[2], enemy_catalog[3]]
		if zone_remaining < ZONE_DURATION * 0.38 and not has_inspector():
			options.append(enemy_catalog[4])
	var data: EnemyData = options[rng.randi_range(0, options.size() - 1)]
	var side := rng.randi_range(0, 3)
	var center: Vector2 = get_camera_center()
	var half_view := Vector2(W * 0.5, H * 0.5)
	var margin := 64.0
	var position := Vector2(rng.randf_range(center.x - half_view.x, center.x + half_view.x), center.y - half_view.y - margin)
	if side == 1: position = Vector2(center.x + half_view.x + margin, rng.randf_range(center.y - half_view.y, center.y + half_view.y))
	if side == 2: position = Vector2(rng.randf_range(center.x - half_view.x, center.x + half_view.x), center.y + half_view.y + margin)
	if side == 3: position = Vector2(center.x - half_view.x - margin, rng.randf_range(center.y - half_view.y, center.y + half_view.y))
	var enemy: Dictionary = acquire_enemy()
	enemy.data = data
	enemy.pos = position
	enemy.hp = data.max_health
	enemy.hit_flash = 0.0
	enemy.touch_clock = 0.0
	enemy.facing = -1.0 if player_pos.x < enemy.pos.x else 1.0
	enemies.append(enemy)

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

func auto_attack() -> void:
	if enemies.is_empty():
		return
	var target: Dictionary = enemies[0]
	var closest: float = player_pos.distance_squared_to(target.pos as Vector2)
	for enemy in enemies:
		var distance: float = player_pos.distance_squared_to(enemy.pos as Vector2)
		if distance < closest:
			closest = distance
			target = enemy
	var projectile: Dictionary = acquire_projectile()
	projectile.pos = player_pos
	projectile.velocity = (target.pos - player_pos).normalized() * (450.0 + 40.0 * int(recipe_levels.get("polenta", 0)))
	projectile.damage = 14.0 + 8.0 * int(recipe_levels.get("polenta", 0))
	projectile.radius = 8.0 + 5.0 * int(recipe_levels.get("polenta", 0))
	projectile.life = 1.65
	projectile.spin_offset = rng.randi_range(0, 3)
	projectiles.append(projectile)
	attack_animation_time = CHEF_ATTACK_DURATION
	AudioManager.play_sfx("burro")

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
		var direction: Vector2 = (player_pos - enemy.pos).normalized()
		if absf(direction.x) > 0.05:
			enemy.facing = signf(direction.x)
		enemy.pos += direction * enemy.data.speed * delta
		if enemy.pos.distance_to(player_pos) < enemy.data.radius + 20.0 and enemy.touch_clock <= 0.0:
			damage_player(enemy.data.contact_damage)
			enemy.touch_clock = 0.7
		if enemy.hp <= 0.0:
			defeat_enemy(index)

func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		projectile.pos += projectile.velocity * delta
		projectile.life -= delta
		var consumed: bool = float(projectile.life) <= 0.0
		if not consumed:
			for enemy in enemies:
				if projectile.pos.distance_to(enemy.pos) < projectile.radius + enemy.data.radius:
					enemy.hp -= projectile.damage
					enemy.hit_flash = 0.12
					consumed = true
					break
		if consumed:
			projectiles.remove_at(index)
			release_projectile(projectile)

func update_drops(delta: float) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.life -= delta
		if drop.pos.distance_to(player_pos) < 46.0:
			inventory[drop.kind] = int(inventory.get(drop.kind, 0)) + 1
			score += 12
			drops.remove_at(index)
			AudioManager.play_sfx("raccolta")
		elif drop.life <= 0.0:
			drops.remove_at(index)

func update_trails(delta: float) -> void:
	for index in range(butter_trails.size() - 1, -1, -1):
		var trail: Dictionary = butter_trails[index]
		trail.life -= delta
		for enemy in enemies:
			if enemy.pos.distance_to(trail.pos) < 34.0:
				enemy.hp -= 12.0 * delta
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
		if caprese_clock > 1.0:
			player_health = minf(player_max_health, player_health + 1.6 * int(recipe_levels.get("caprese", 0)))
			caprese_clock = 0.0
	if int(recipe_levels.get("tagliatelle", 0)) > 0:
		trail_clock += delta
		if trail_clock > 0.35:
			butter_trails.append({"pos": player_pos, "life": 2.2})
			trail_clock = 0.0
	if int(recipe_levels.get("porchetta", 0)) > 0:
		porchetta_clock += delta
		if porchetta_clock > 0.32:
			for enemy in enemies:
				if enemy.pos.distance_to(player_pos) < 95.0:
					enemy.hp -= 19.0 * int(recipe_levels.get("porchetta", 0))
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
	score += 30 if enemy.data.id != "ispettore" else 450
	deaths.append({
		"id": String(enemy.data.id),
		"pos": enemy.pos,
		"facing": float(enemy.get("facing", 1.0)),
		"time": 0.0,
		"duration": 0.72,
	})
	var count: int = 3 if enemy.data.id == "ispettore" else 1
	for amount in count:
		var ingredient = enemy.data.drops[rng.randi_range(0, enemy.data.drops.size() - 1)]
		drops.append({"kind": ingredient, "pos": enemy.pos + Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18)), "life": 11.0})
	enemies.remove_at(index)
	release_enemy(enemy)
	AudioManager.play_sfx("sconfitto")

func finish_zone() -> void:
	for enemy in enemies:
		release_enemy(enemy)
	enemies.clear()
	projectiles.clear()
	deaths.clear()
	if zone_index >= ZONES.size() - 1:
		show_dinner()
	else:
		show_cooking()

func show_cooking() -> void:
	state = GameState.COOKING
	clear_overlay()
	var panel := make_panel(Rect2(40, 205, 640, 790), Color("#293b20"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(30, 26), Vector2(580, 62), 34)
	heading.text = "FERMATA IN CUCINA"
	panel.add_child(heading)
	var explanation := make_label(Vector2(44, 88), Vector2(552, 62), 17)
	explanation.text = "Scegli una ricetta con la dispensa raccolta."
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
		var continue_button := make_button("VAI ALLA CENA", Rect2(120, 650, 400, 72), 22)
		continue_button.pressed.connect(show_dinner)
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
	zone_index += 1
	zone_remaining = ZONE_DURATION
	spawn_clock = 1.0
	state = GameState.PLAYING
	clear_overlay()
	AudioManager.play_sfx("cucina")
	update_hud()

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
	player_pos += dash_direction * 120.0
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
	var recipe_value: int = RunState.completed_recipes.size() * 260
	var freshness: int = int(player_health * 3.0)
	var wine_pairing: int = int(inventory.get("vino", 0)) * 35
	score += ingredient_value + recipe_value + freshness + wine_pairing
	RunState.score = score
	was_new_best = SaveData.set_best_score(score)
	var panel := make_panel(Rect2(42, 220, 636, 760), Color("#38291d"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(24, 34), Vector2(588, 62), 38)
	heading.text = "È ORA DI CENA!"
	heading.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(heading)
	var text := make_label(Vector2(66, 135), Vector2(504, 330), 22, HORIZONTAL_ALIGNMENT_LEFT)
	text.text = "Qualità delle ricette  +%d\nFreschezza               +%d\nAbbinamento vino       +%d\nDispensa rimasta       +%d\n\nTOTALE                    %d" % [recipe_value, freshness, wine_pairing, ingredient_value, score]
	text.add_theme_color_override("font_color", Color("#fff4d6"))
	panel.add_child(text)
	var verdict := make_label(Vector2(65, 505), Vector2(506, 58), 20)
	verdict.text = "NUOVO RECORD!" if was_new_best else "Gli ospiti chiedono il bis."
	verdict.add_theme_color_override("font_color", Color("#f5cb56"))
	panel.add_child(verdict)
	var again := make_button("UN'ALTRA SAGRA", Rect2(90, 610, 456, 70), 22)
	again.pressed.connect(start_run)
	panel.add_child(again)

func show_game_over() -> void:
	state = GameState.GAME_OVER
	clear_overlay()
	var panel := make_panel(Rect2(66, 365, 588, 450), Color("#3e261d"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(28, 42), Vector2(532, 70), 36)
	heading.text = "PADELLA VUOTA!"
	panel.add_child(heading)
	var message := make_label(Vector2(42, 135), Vector2(504, 90), 20)
	message.text = "La fame ha avuto la meglio.\nPunti raccolti: %d" % score
	panel.add_child(message)
	var retry := make_button("RIPROVA", Rect2(85, 285, 418, 72), 24)
	retry.pressed.connect(start_run)
	panel.add_child(retry)

func show_pause() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	clear_overlay()
	var panel := make_panel(Rect2(130, 440, 460, 300), Color("#26391f"), Color("#f3d47c"))
	overlay.add_child(panel)
	var heading := make_label(Vector2(20, 35), Vector2(420, 56), 32)
	heading.text = "PAUSA"
	panel.add_child(heading)
	var resume := make_button("TORNA ALLA SAGRA", Rect2(65, 160, 330, 70), 20)
	resume.pressed.connect(resume_game)
	panel.add_child(resume)

func resume_game() -> void:
	state = GameState.PLAYING
	clear_overlay()

func update_hud() -> void:
	if state != GameState.PLAYING:
		return
	hud_labels.zone.text = ZONES[zone_index]
	var remaining_seconds := int(maxf(0.0, zone_remaining))
	hud_labels.timer.text = "%02d:%02d" % [floori(remaining_seconds / 60.0), remaining_seconds % 60]
	hud_labels.health.text = "♥ %d / %d" % [int(player_health), int(player_max_health)]
	hud_labels.score.text = "✦ %d" % score
	var compact := ""
	for key in ["guanciale", "olio", "formaggio", "vino"]:
		compact += "%s:%d  " % [INGREDIENT_LABELS[key].left(3), int(inventory.get(key, 0))]
	hud_labels.pantry.text = compact.strip_edges()
	dash_button.text = "SCATTO" if elapsed_run >= dash_ready_at else "ATTENDI"

func _draw() -> void:
	draw_pixel_background()
	for trail in butter_trails:
		draw_circle(trail.pos, 18.0, Color(1.0, 0.85, 0.35, 0.42))
	for death in deaths:
		draw_enemy_death(death)
	for drop in drops:
		draw_ingredient_drop(drop)
	for projectile in projectiles:
		draw_butter_projectile(projectile)
	for enemy in enemies:
		draw_enemy(enemy)
	draw_player()
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
		_:
			draw_vigneto_tile(origin, variation, grid_x)

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

func draw_player() -> void:
	if int(recipe_levels.get("caprese", 0)) > 0:
		draw_arc(player_pos, 47.0, 0.0, TAU, 24, Color(0.36, 0.92, 0.36, 0.38), 4.0)
	if int(recipe_levels.get("porchetta", 0)) > 0:
		var blade := player_pos + Vector2(72, 0).rotated(elapsed_run * 5.0)
		draw_circle(blade, 23.0, Color("#9e3d1e"))
		draw_circle(blade, 15.0, Color("#efad56"))
	var texture := CHEF_IDLE_TEXTURE
	var frame := floori(elapsed_run * 10.0) % CHEF_ANIMATION_FRAMES if player_is_moving else 0
	if attack_animation_time > 0.0:
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
	draw_set_transform(player_pos, 0.0, Vector2(player_facing, 1.0))
	draw_texture_rect_region(texture, destination, source, modulation)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_butter_projectile(projectile: Dictionary) -> void:
	var radius: float = float(projectile.radius)
	var frame: int = (floori(elapsed_run * 14.0) + int(projectile.get("spin_offset", 0))) % 4
	var draw_size: float = clampf(34.0 + radius * 1.4, 40.0, 58.0)
	var source: Rect2 = Rect2(Vector2(frame * 64, 0), Vector2(64, 64))
	var destination: Rect2 = Rect2(projectile.pos - Vector2.ONE * draw_size * 0.5, Vector2.ONE * draw_size)
	draw_circle(projectile.pos + Vector2(3, 5), radius + 2.0, Color(0.15, 0.08, 0.04, 0.24))
	draw_texture_rect_region(BUTTER_PROJECTILE_TEXTURE, destination, source)

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
	var texture: Texture2D = ENEMY_TURISTA_DEATH_TEXTURE
	var draw_size: float = 108.0
	match enemy_id:
		"ispettore":
			texture = ENEMY_ISPETTORE_DEATH_TEXTURE
			draw_size = 140.0
		"ladro":
			texture = ENEMY_LADRO_DEATH_TEXTURE
			draw_size = 112.0
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
		draw_circle(pos, enemy.data.radius, Color("#fff7df"))
		draw_circle(pos + Vector2(12 * facing, -14), 11, Color("#fff7df"))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(21 * facing, -14),
			pos + Vector2(34 * facing, -9),
			pos + Vector2(21 * facing, -4),
		]), Color("#e8a534"))
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

func draw_human_enemy(enemy: Dictionary) -> void:
	var texture: Texture2D = ENEMY_TURISTA_TEXTURE
	var draw_size: float = 108.0
	match String(enemy.data.id):
		"ispettore":
			texture = ENEMY_ISPETTORE_TEXTURE
			draw_size = 140.0
		"ladro":
			texture = ENEMY_LADRO_TEXTURE
			draw_size = 112.0
	var phase: float = elapsed_run * 10.0 + float(enemy.pos.x) * 0.013
	var frame: int = floori(phase) % ENEMY_ANIMATION_FRAMES
	var source: Rect2 = Rect2(Vector2(frame * 128, 0), CHEF_FRAME_SIZE)
	var size: Vector2 = Vector2(draw_size, draw_size)
	var destination: Rect2 = Rect2(enemy.pos - Vector2(draw_size * 0.5, draw_size * 0.72), size)
	var modulation: Color = Color.WHITE
	if enemy.hit_flash > 0.0:
		modulation = Color(1.0, 0.58, 0.58, 1.0)
	var facing: float = float(enemy.get("facing", 1.0))
	destination.position -= enemy.pos
	draw_set_transform(enemy.pos, 0.0, Vector2(facing, 1.0))
	draw_texture_rect_region(texture, destination, source, modulation)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if enemy.hit_flash > 0.0:
		draw_arc(enemy.pos, enemy.data.radius + 5.0, 0.0, TAU, 12, Color.WHITE, 2.0)

func draw_virtual_joystick() -> void:
	var screen_origin: Vector2 = get_camera_center() - Vector2(W, H) * 0.5
	var world_center: Vector2 = screen_origin + joystick_center
	draw_circle(world_center, 74.0, Color(0.12, 0.18, 0.1, 0.24))
	draw_arc(world_center, 74.0, 0.0, TAU, 28, Color(1.0, 0.95, 0.75, 0.45), 3.0)
	draw_circle(world_center + joystick_vector * 45.0, 30.0, Color(0.96, 0.78, 0.33, 0.58))
