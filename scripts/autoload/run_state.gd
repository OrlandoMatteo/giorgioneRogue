extends Node

var seed_value := 0
var score := 0
var zone_index := 0
var completed_recipes: Array[String] = []
var ingredients := {}

func begin_run() -> void:
	seed_value = randi()
	score = 0
	zone_index = 0
	completed_recipes.clear()
	ingredients.clear()

