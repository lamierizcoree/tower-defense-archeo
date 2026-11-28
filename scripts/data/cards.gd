class_name Cards
extends RefCounted
## Les cartes du deck. On ne pose plus les tours avec un budget libre : chaque niveau,
## on pioche une main dans son deck et on joue des cartes en payant leur prix en or.
##
## - Deck de DECK_SIZE cartes, construit au camp de base parmi les cartes débloquées.
## - Main de départ : DRAW_START cartes, avec au moins une carte de tour et une carte de murs.
##   Puis DRAW_PER_WAVE cartes de plus après chaque vague. Main limitée à HAND_MAX.
## - Pioche vide : la défausse est remélangée et forme une nouvelle pioche.
## - BASE_WALLS murs gratuits au début de chaque niveau ; les cartes de murs en ajoutent.
## - Chaque carte s'améliore 2 fois au plus (MAX_LEVEL), pour toute l'expédition :
##   une amélioration après chaque victoire, et d'autres en sacrifiant une relique.
##
## Types de cartes :
##   walls  : ajoute des murs à poser ("walls" par niveau d'amélioration)
##   tower  : pose une tour sur un mur ("tower" = identifiant dans tower_types.gd)
##   trap   : piège posé sur une case libre ; les ennemis qui passent dessus le déclenchent
##   curse  : malus pour les ennemis pendant quelques vagues
##   boost  : bonus pour les tours pendant quelques vagues
## Pour les tours, le prix est celui de la tour (tower_types.gd).

const DECK_SIZE := 20
const DRAW_START := 5
const DRAW_PER_WAVE := 3
const HAND_MAX := 9
const BASE_WALLS := 5
const MAX_LEVEL := 2
const MAX_COPIES := 6
const TOWER_DISCOUNT := 0.7      # carte de tour améliorée 1 fois : 30 % moins chère
const RELIC_ENGRAVE := 1         # amélioration gagnée en sacrifiant une relique

const KINDS := {
	"walls": {"name": "Construction", "color": Color("b08a5a")},
	"tower": {"name": "Tour", "color": Color("6fa8dc")},
	"trap": {"name": "Piège", "color": Color("e07b5a")},
	"curse": {"name": "Malus ennemis", "color": Color("b07fd6")},
	"boost": {"name": "Bonus tours", "color": Color("8fdc6a")},
}

## Ordre d'affichage. unlock = rang d'archéologue nécessaire.
## Pour les cartes à durée, "waves" donne le nombre de vagues par niveau d'amélioration (0, 1, 2).
const DATA := {
	"murs": {"name": "Pierres taillées", "short": "Pierres", "kind": "walls", "cost": 3, "unlock": 0,
		"walls": [3, 4, 5]},
	"arbalete": {"name": "Arbalète", "kind": "tower", "tower": "arbalete", "unlock": 0},
	"baliste": {"name": "Baliste", "kind": "tower", "tower": "baliste", "unlock": 0},
	"mortier": {"name": "Mortier", "kind": "tower", "tower": "mortier", "unlock": 0},
	"givre": {"name": "Givre", "kind": "tower", "tower": "givre", "unlock": 0},
	"alambic": {"name": "Alambic", "kind": "tower", "tower": "alambic", "unlock": 0},
	"totem": {"name": "Totem", "kind": "tower", "tower": "totem", "unlock": 0},
	"pointes": {"name": "Fosse à pieux", "short": "Pieux", "kind": "trap", "cost": 8, "unlock": 0,
		"damage": [30.0, 40.0, 50.0], "waves": [1, 2, 3]},
	"lampe": {"name": "Huile de lampe", "short": "Huile", "kind": "boost", "cost": 10, "unlock": 0,
		"rate": 0.25, "waves": [1, 2, 3]},
	"glu": {"name": "Résine collante", "short": "Résine", "kind": "trap", "cost": 6, "unlock": 2,
		"slow": 0.5, "slow_time": [2.0, 2.5, 3.0], "waves": [1, 2, 3]},
	"aiguiser": {"name": "Pierre à aiguiser", "short": "Aiguiser", "kind": "boost", "cost": 10, "unlock": 3,
		"damage": 0.25, "waves": [1, 2, 3]},
	"lenteur": {"name": "Bandelettes lourdes", "short": "Bandelettes", "kind": "curse", "cost": 10, "unlock": 5,
		"speed": 0.8, "waves": [1, 2, 3]},
	"fragilite": {"name": "Malédiction des os", "short": "Os maudits", "kind": "curse", "cost": 12, "unlock": 7,
		"vulnerable": 0.2, "waves": [1, 2, 3]},
}

## Deck de départ, si le joueur n'en a pas construit (20 cartes).
const DEFAULT_DECK := {
	"murs": 6, "arbalete": 4, "givre": 2, "baliste": 2, "mortier": 1,
	"alambic": 1, "totem": 1, "pointes": 2, "lampe": 1,
}


static func get_card(id: String) -> Dictionary:
	return DATA[id]


## Nom court, pour la main pendant le niveau.
static func short_name(id: String) -> String:
	return DATA[id].get("short", DATA[id]["name"])


static func kind_of(id: String) -> String:
	return DATA[id]["kind"]


static func color_of(id: String) -> Color:
	if kind_of(id) == "tower":
		return TowerTypes.get_type(DATA[id]["tower"])["color"]
	return KINDS[kind_of(id)]["color"]


## Prix de base en or (sans les jokers).
static func base_cost(id: String, lvl: int) -> int:
	var c: Dictionary = DATA[id]
	if c["kind"] == "tower":
		var cost: float = TowerTypes.get_type(c["tower"])["cost"]
		if lvl >= 1:
			cost *= TOWER_DISCOUNT
		return int(ceil(cost))
	return int(c["cost"])


## Nombre de vagues que dure l'effet (pièges, malus, bonus).
static func waves_of(id: String, lvl: int) -> int:
	return int(DATA[id].get("waves", [0, 0, 0])[lvl])


## Ce que fait la carte, au niveau d'amélioration donné.
static func describe(id: String, lvl: int) -> String:
	var c: Dictionary = DATA[id]
	var w := waves_of(id, lvl)
	var dur := "%d vague%s" % [w, "s" if w > 1 else ""]
	match c["kind"]:
		"walls":
			return "+%d murs à poser" % c["walls"][lvl]
		"tower":
			var t := TowerTypes.get_type(c["tower"])
			var s: String = "Pose une tour %s sur un mur. %s." % [t["name"], t["desc"]]
			if lvl >= 1:
				s += " 30 % moins chère."
			if lvl >= 2:
				s += " Arrive au niveau 2."
			return s
		"trap":
			if id == "pointes":
				return "Piège sur une case libre : %d dégâts à chaque ennemi qui passe. Dure %s." % [c["damage"][lvl], dur]
			return "Piège sur une case libre : ralentit de %d %% pendant %s s. Dure %s." % [roundi((1.0 - c["slow"]) * 100), _num(c["slow_time"][lvl]), dur]
		"curse":
			if c.has("speed"):
				return "Ennemis %d %% plus lents pendant %s." % [roundi((1.0 - c["speed"]) * 100), dur]
			return "Ennemis : +%d %% de dégâts subis pendant %s." % [roundi(c["vulnerable"] * 100), dur]
		"boost":
			if c.has("rate"):
				return "Tours +%d %% de cadence pendant %s." % [roundi(c["rate"] * 100), dur]
			return "Tours +%d %% de dégâts pendant %s." % [roundi(c["damage"] * 100), dur]
	return ""


## Ce que change la prochaine amélioration ("" si la carte est au maximum).
static func upgrade_text(id: String, lvl: int) -> String:
	if lvl >= MAX_LEVEL:
		return ""
	var c: Dictionary = DATA[id]
	match c["kind"]:
		"walls":
			return "+%d murs au lieu de +%d" % [c["walls"][lvl + 1], c["walls"][lvl]]
		"tower":
			return "30 % moins chère" if lvl == 0 else "La tour arrive au niveau 2"
		"trap":
			var s := "Dure %d vagues" % waves_of(id, lvl + 1)
			if id == "pointes":
				s += ", %d dégâts" % c["damage"][lvl + 1]
			else:
				s += ", ralentit %s s" % _num(c["slow_time"][lvl + 1])
			return s
	return "Dure %d vagues au lieu de %d" % [waves_of(id, lvl + 1), waves_of(id, lvl)]


static func _num(x: float) -> String:
	if absf(x - roundf(x)) < 0.05:
		return str(roundi(x))
	return ("%.1f" % x).replace(".", ",")


static func is_unlocked(id: String, rank: int) -> bool:
	return rank >= int(DATA[id].get("unlock", 0))


## Pourquoi ce deck n'est pas jouable ("" s'il est bon).
static func deck_problem(counts: Dictionary) -> String:
	var total := 0
	var towers := 0
	var walls := 0
	for id in counts:
		var n: int = counts[id]
		total += n
		if kind_of(id) == "tower":
			towers += n
		elif kind_of(id) == "walls":
			walls += n
	if total != DECK_SIZE:
		return "Le deck doit contenir %d cartes (%d pour l'instant)." % [DECK_SIZE, total]
	if towers == 0:
		return "Il faut au moins une carte de tour."
	if walls == 0:
		return "Il faut au moins une carte de murs."
	return ""


## Liste de cartes ({"id", "lvl"}) à partir d'un nombre d'exemplaires par carte.
static func build(counts: Dictionary) -> Array:
	var deck := []
	for id in DATA:
		for i in int(counts.get(id, 0)):
			deck.append({"id": id, "lvl": 0})
	return deck
