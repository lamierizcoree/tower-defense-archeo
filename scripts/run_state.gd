extends Node
## L'expédition en cours (la « run ») : carte, vies, jokers et score.
## Ce script est chargé automatiquement au lancement sous le nom « Run » (voir project.godot),
## ce qui permet à tous les écrans d'y accéder.

const START_LIVES := 20

var rng := RandomNumberGenerator.new()
var started := false
var biome_index := 0
var map: Array = []                 # voir map_gen.gd
var current := Vector2i(-1, -1)     # (étage, index) du niveau en cours ; -1 = au départ de la carte
var visited: Array[Vector2i] = []   # niveaux déjà joués dans ce biome
var lives := START_LIVES
var jokers: Array[String] = []
var score := 0
var kills := 0
var levels_cleared := 0
var victory := false


func new_run() -> void:
	rng.randomize()
	started = true
	biome_index = 0
	lives = START_LIVES
	jokers.clear()
	score = 0
	kills = 0
	levels_cleared = 0
	victory = false
	_start_biome()


func _start_biome() -> void:
	map = MapGen.generate(rng, biome_index)
	current = Vector2i(-1, -1)
	visited.clear()


func biome() -> Dictionary:
	return Biomes.get_biome(biome_index)


func has_joker(id: String) -> bool:
	return id in jokers


func current_node() -> Dictionary:
	return map[current.x][current.y]


## Les niveaux que le joueur peut choisir maintenant sur la carte.
func reachable() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if current.x < 0:
		for i in map[0].size():
			result.append(Vector2i(0, i))
	elif current.x + 1 < map.size():
		for j in current_node()["links"]:
			result.append(Vector2i(current.x + 1, j))
	return result


func enter_level(pos: Vector2i) -> void:
	current = pos
	visited.append(pos)
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func level_won() -> void:
	levels_cleared += 1
	score += 100 * (biome_index + 1)
	if current_node()["type"] == "boss" and biome_index == Biomes.count() - 1:
		victory = true
		score += lives * 20
		get_tree().change_scene_to_file("res://scenes/end.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/reward.tscn")


func level_lost() -> void:
	victory = false
	get_tree().change_scene_to_file("res://scenes/end.tscn")


## Appelé quand la récompense est choisie : retour à la carte, ou biome suivant après un boss.
func reward_done() -> void:
	if current_node()["type"] == "boss":
		biome_index += 1
		_start_biome()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
