extends Node

const SAVE_PATH := "user://giorgiones_feast_save.json"
var data := {
	"best_score": 0,
	"unlocked_recipes": [],
	"kitchen_level": 0,
	"music_enabled": true,
	"sfx_enabled": true,
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

