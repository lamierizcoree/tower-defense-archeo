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
var relics: Array[String] = []     # inventaire de reliques (voir data/relics.gd)
var score := 0
var kills := 0
var levels_cleared := 0
var victory := false
var treasure := 0                   # trésor : la moitié de l'or restant à la fin de chaque niveau, dépensé chez le marchand
var mission := ""                   # mission de la fouille en cours (voir data/missions.gd)
var mission_ok := false
var difficulty := 0                 # niveau de difficulté de l'expédition (voir data/difficulty.gd)
var difficulty_unlocked_now := false  # cette expédition a débloqué un nouveau niveau
var score_bonus := 0                # score ajouté par la difficulté à la fin
var boss_killed := false            # le boss du niveau en cours a-t-il été tué ?
var new_unlocks: Array[String] = []   # reliques débloquées au dernier niveau réussi
var points_gained := 0               # points d'amélioration gagnés à la fin de l'expédition
var finished := false
var codex_return := "res://scenes/hub.tscn"   # écran où revenir en quittant le carnet
var forge_free := false             # fusion offerte par le feu de camp


func new_run() -> void:
	rng.randomize()
	started = true
	difficulty = Profile.difficulty
	difficulty_unlocked_now = false
	score_bonus = 0
	biome_index = 0
	lives = START_LIVES + Profile.bonus_lives()
	if Difficulty.has(difficulty, "vies"):
		lives = maxi(1, lives - Difficulty.LIVES_MALUS)
	jokers.clear()
	relics.clear()
	if Profile.starting_relic():
		relics.append(Relics.draw(rng, "commun", 0.0, Profile.is_relic_unlocked))
	score = 0
	treasure = 0
	kills = 0
	levels_cleared = 0
	victory = false
	finished = false
	new_unlocks.clear()
	_start_biome()


func _start_biome() -> void:
	map = MapGen.generate(rng, biome_index)
	current = Vector2i(-1, -1)
	visited.clear()


func biome() -> Dictionary:
	return Biomes.get_biome(biome_index)


func has_joker(id: String) -> bool:
	return id in jokers


## Clan de jokers au palier voulu (2 ou 3) ?
func has_family(family: String, step: int) -> bool:
	return Jokers.family_count(jokers, family) >= step


func has_duo(duo: String) -> bool:
	return Jokers.has_duo(jokers, duo)


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
	boss_killed = false
	var type: String = current_node()["type"]
	match type:
		"shop":
			get_tree().change_scene_to_file("res://scenes/shop.tscn")
		"event":
			get_tree().change_scene_to_file("res://scenes/event.tscn")
		"camp":
			get_tree().change_scene_to_file("res://scenes/camp.tscn")
		_:
			mission = Missions.random_id(rng) if type == "fouille" else ""
			mission_ok = false
			get_tree().change_scene_to_file("res://scenes/level.tscn")


## Fin d'une étape sans combat (marchand, événement, camp) : retour à la carte.
func stop_done() -> void:
	get_tree().change_scene_to_file("res://scenes/map.tscn")


## Ajoute une relique tirée au hasard (rareté minimale). Si l'inventaire est plein,
## elle est revendue : renvoie le nom de la relique, ou un texte qui explique la vente.
func gain_relic(min_rarity: String) -> String:
	var id := Relics.draw(rng, min_rarity, Profile.luck(), Profile.is_relic_unlocked)
	var r := Relics.get_relic(id)
	if relics.size() >= Relics.MAX_HELD:
		treasure += 30
		return "%s (inventaire plein : revendue 30 trésor)" % r["name"]
	relics.append(id)
	return "%s (%s)" % [r["name"], Relics.RARITY_NAMES[r["rarity"]].to_lower()]


## Ajoute un joker d'une rareté donnée (ou la plus proche disponible).
func gain_joker(rarity: String) -> String:
	if jokers.size() >= Profile.max_jokers():
		treasure += 30
		return "aucun joker (main pleine : +30 trésor)"
	var pool := []
	var others := []
	for id in Jokers.DATA:
		if id in jokers:
			continue
		if Jokers.rarity_of(id) == rarity:
			pool.append(id)
		else:
			others.append(id)
	if pool.is_empty():
		pool = others
	if pool.is_empty():
		return "aucun joker disponible"
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	jokers.append(pick)
	return Jokers.get_joker(pick)["name"]


func level_won() -> void:
	levels_cleared += 1
	score += 100 * (biome_index + 1)
	var boss_id: String = biome()["boss"] if current_node()["type"] == "boss" and boss_killed else ""
	new_unlocks = Profile.level_cleared(boss_id)
	if current_node()["type"] == "boss" and biome_index == Biomes.count() - 1:
		victory = true
		score += lives * 20
		_finish()
		get_tree().change_scene_to_file("res://scenes/end.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/reward.tscn")


func level_lost() -> void:
	victory = false
	_finish()
	get_tree().change_scene_to_file("res://scenes/end.tscn")


## Fin de l'expédition : le score part dans le profil et donne des points d'amélioration.
func _finish() -> void:
	finished = true
	started = false
	score_bonus = roundi(score * (Difficulty.score_mult(difficulty) - 1.0))
	score += score_bonus
	points_gained = Profile.run_finished(score, victory)


## Appelé quand la récompense est choisie : retour à la carte, ou biome suivant après un boss.
func reward_done() -> void:
	if current_node()["type"] == "boss":
		biome_index += 1
		_start_biome()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
