extends Node
## Le profil du joueur, gardé d'une expédition à l'autre et sauvegardé sur le disque.
## Chargé automatiquement sous le nom « Profile » (voir project.godot).
##
## - Le rang d'archéologue monte de 1 à chaque niveau réussi, toutes expéditions confondues.
##   Il débloque de nouvelles reliques (voir le champ « unlock » dans data/relics.gd).
## - Le score cumulé donne des points d'amélioration (voir data/upgrades.gd).

const SAVE_PATH := "user://profil.json"

var rank := 0                 # niveaux réussis au total
var total_score := 0
var best_score := 0
var runs := 0
var victories := 0
var bosses := {}              # identifiant du boss -> nombre de victoires
var alloc := {}               # catégorie d'amélioration -> points
var difficulty_unlocked := 0  # plus haut niveau de difficulté débloqué (voir data/difficulty.gd)
var difficulty := 0           # niveau choisi pour la prochaine expédition


func _ready() -> void:
	load_profile()


# --- Sauvegarde --------------------------------------------------------------

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	rank = int(data.get("rank", 0))
	total_score = int(data.get("total_score", 0))
	best_score = int(data.get("best_score", 0))
	runs = int(data.get("runs", 0))
	victories = int(data.get("victories", 0))
	bosses = data.get("bosses", {})
	difficulty_unlocked = clampi(int(data.get("difficulty_unlocked", 0)), 0, Difficulty.MAX)
	difficulty = clampi(int(data.get("difficulty", 0)), 0, difficulty_unlocked)
	alloc = {}
	var saved_alloc: Dictionary = data.get("alloc", {})
	for k in saved_alloc:
		if Upgrades.DATA.has(k):
			alloc[k] = int(saved_alloc[k])


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"rank": rank, "total_score": total_score, "best_score": best_score,
		"runs": runs, "victories": victories, "bosses": bosses, "alloc": alloc,
		"difficulty_unlocked": difficulty_unlocked, "difficulty": difficulty,
	}, "  "))


## Remet le profil à zéro (bouton du camp de base).
func reset() -> void:
	rank = 0
	total_score = 0
	best_score = 0
	runs = 0
	victories = 0
	bosses = {}
	alloc = {}
	difficulty_unlocked = 0
	difficulty = 0
	save_profile()


# --- Rang et déblocages ------------------------------------------------------

func is_relic_unlocked(id: String) -> bool:
	return rank >= int(Relics.get_relic(id).get("unlock", 0))


## Appelé à chaque niveau réussi. Renvoie les reliques débloquées par ce nouveau rang.
func level_cleared(boss_id := "") -> Array[String]:
	var before := rank
	rank += 1
	if boss_id != "":
		bosses[boss_id] = int(bosses.get(boss_id, 0)) + 1
	save_profile()
	var unlocked: Array[String] = []
	for id in Relics.DATA:
		var need := int(Relics.get_relic(id).get("unlock", 0))
		if need > before and need <= rank:
			unlocked.append(id)
	return unlocked


## La prochaine relique à débloquer : [rang nécessaire, identifiant], ou [] si tout est débloqué.
func next_unlock() -> Array:
	var best := []
	for id in Relics.DATA:
		var need := int(Relics.get_relic(id).get("unlock", 0))
		if need > rank and (best.is_empty() or need < best[0]):
			best = [need, id]
	return best


## Appelé à la fin d'une expédition. Renvoie le nombre de points d'amélioration gagnés.
func run_finished(score: int, victory: bool) -> int:
	var before := points_earned()
	runs += 1
	if victory:
		victories += 1
		# Réussir au niveau le plus haut débloqué ouvre le suivant.
		if Run.difficulty >= difficulty_unlocked and difficulty_unlocked < Difficulty.MAX:
			difficulty_unlocked += 1
			Run.difficulty_unlocked_now = true
	total_score += score
	best_score = maxi(best_score, score)
	save_profile()
	return points_earned() - before


## Change la difficulté choisie au camp de base (step = -1 ou +1).
func change_difficulty(step: int) -> void:
	difficulty = clampi(difficulty + step, 0, difficulty_unlocked)
	save_profile()


# --- Améliorations -----------------------------------------------------------

func points_earned() -> int:
	return Upgrades.points_for_score(total_score)


## Score cumulé qu'il faut atteindre pour le prochain point (-1 si le plafond est atteint).
func next_point_score() -> int:
	var n := points_earned()
	if n >= Upgrades.CAP:
		return -1
	return Upgrades.score_for_points(n + 1)


## Points qu'on peut répartir : ceux gagnés, dans la limite du plafond.
func points_available() -> int:
	return mini(points_earned(), Upgrades.CAP)


func points_used() -> int:
	var total := 0
	for k in alloc:
		total += int(alloc[k])
	return total


func level_of(category: String) -> int:
	return int(alloc.get(category, 0))


func can_add(category: String) -> bool:
	return not Upgrades.get_upgrade(category).get("disabled", false) \
		and level_of(category) < Upgrades.MAX_PER_CATEGORY \
		and points_used() < points_available()


func add_point(category: String) -> void:
	if can_add(category):
		alloc[category] = level_of(category) + 1
		save_profile()


func remove_point(category: String) -> void:
	if level_of(category) > 0:
		alloc[category] = level_of(category) - 1
		save_profile()


func clear_points() -> void:
	alloc = {}
	save_profile()


## Multiplicateurs et bonus utilisés pendant le jeu.
func damage_mult() -> float:
	return 1.0 + 0.01 * level_of("puissance")


func rate_mult() -> float:
	return 1.0 + 0.01 * level_of("cadence")


func wave_gold() -> int:
	return 5 * level_of("economie")


## Amélioration Forge : prix des fusions de reliques.
func forge_mult() -> float:
	return 1.0 - 0.03 * level_of("forge")


func bonus_lives() -> int:
	return level_of("rempart")


## Stat Chance, de 0 (aucun point) à 1 (10 points) : voir Relics.lucky_weights.
func luck() -> float:
	return float(level_of("chance")) / Upgrades.MAX_PER_CATEGORY


func max_jokers() -> int:
	return Jokers.MAX_HELD + (1 if level_of("preparation") >= 10 else 0)


func starting_relic() -> bool:
	return level_of("preparation") >= 5
