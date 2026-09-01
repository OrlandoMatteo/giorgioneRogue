extends Node

const SAVE_PATH := "user://giorgiones_feast_save.json"
var data := {
	"best_score": 0,
	"leaderboard": [],
	"unlocked_recipes": [],
	"kitchen_level": 0,
	"music_enabled": true,
	"sfx_enabled": true,
	"online_username": "",
	"online_player_id": "",
	"pending_online_score": {},
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			data[key] = parsed[key]
	if not data.leaderboard is Array:
		data.leaderboard = []
	if data.leaderboard.is_empty() and int(data.best_score) > 0:
		data.leaderboard.append({
			"score": int(data.best_score), "kills": 0, "zones": 3,
			"endless_seconds": 0, "legacy": true,
		})
		save()

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func unlock_recipe(recipe_id: String) -> void:
	if recipe_id not in data.unlocked_recipes:
		data.unlocked_recipes.append(recipe_id)
		save()

func set_best_score(value: int) -> bool:
	if value <= int(data.best_score):
		return false
	data.best_score = value
	save()
	return true

func record_run(value: int, kills: int, zones: int, endless_seconds: int) -> bool:
	var entry := {
		"score": value,
		"kills": kills,
		"zones": clampi(zones, 0, 5),
		"endless_seconds": maxi(0, endless_seconds),
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	data.leaderboard.append(entry)
	data.leaderboard.sort_custom(_score_is_higher)
	if data.leaderboard.size() > 10:
		data.leaderboard.resize(10)
	var is_new_best := value > int(data.best_score)
	if is_new_best:
		data.best_score = value
	save()
	return is_new_best

func get_leaderboard() -> Array:
	return data.leaderboard.duplicate(true)

func set_online_identity(username: String, player_id: String) -> void:
	data.online_username = username
	data.online_player_id = player_id
	save()

func clear_online_identity() -> void:
	data.online_username = ""
	data.online_player_id = ""
	data.pending_online_score = {}
	save()

func has_online_identity() -> bool:
	return not String(data.online_username).is_empty() and not String(data.online_player_id).is_empty()

func set_pending_online_score(run_data: Dictionary) -> void:
	data.pending_online_score = run_data.duplicate(true)
	save()

func clear_pending_online_score() -> void:
	data.pending_online_score = {}
	save()

func _score_is_higher(first: Dictionary, second: Dictionary) -> bool:
	return int(first.get("score", 0)) > int(second.get("score", 0))
