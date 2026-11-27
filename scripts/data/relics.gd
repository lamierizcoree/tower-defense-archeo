class_name Relics
extends RefCounted
## Les reliques : des artefacts déterrés qu'on place dans les emplacements des tours.
## On les gagne dans les récompenses. Pendant un niveau, on les pose dans les tours
## avec la barre de reliques ; elles reviennent dans l'inventaire au niveau suivant.
##
## unlock : rang d'archéologue nécessaire pour trouver la relique (voir profile.gd).
##
## Bonus en pourcentage (0.15 = +15 %) :
##   damage : dégâts      rate : cadence de tir      range : portée
##   effect : effets spéciaux (ralentissement, poison, rayon d'explosion, bonus du Totem)
## Bonus des légendaires (un gros bonus, mais une contrainte) :
##   damage_x / rate_x : multiplicateurs
##   line : la tour tire en ligne droite dans une direction, sur autant de cases que sa portée de base
##   fixed_range : portée imposée, en pixels
##   only_slowed : la tour ne vise que les ennemis ralentis
## Effets spéciaux :
##   seal : les murs à portée de la tour ne peuvent plus être creusés par les fouisseurs

const MAX_HELD := 8

const RARITIES := ["commun", "non_commun", "rare", "legendaire"]
const RARITY_NAMES := {"commun": "Commune", "non_commun": "Peu commune", "rare": "Rare", "legendaire": "Légendaire"}
const RARITY_COLORS := {
	"commun": Color("b8b2a6"),
	"non_commun": Color("5cc46a"),
	"rare": Color("4f8fe0"),
	"legendaire": Color("f0a030"),
}
## Chances de tirer chaque rareté dans une récompense normale.
const WEIGHTS := {"commun": 50, "non_commun": 30, "rare": 15, "legendaire": 5}

const DATA := {
	# --- Communes : +15 % ---
	"silex": {"name": "Pointe de silex", "rarity": "commun", "unlock": 0, "damage": 0.15},
	"plume": {"name": "Plume de vautour", "rarity": "commun", "unlock": 0, "rate": 0.15},
	"lentille": {"name": "Lentille fêlée", "rarity": "commun", "unlock": 0, "range": 0.15},
	# --- Peu communes : +25 % ---
	"amulette": {"name": "Amulette de bronze", "rarity": "non_commun", "unlock": 0, "damage": 0.25},
	"rouage": {"name": "Rouage ancien", "rarity": "non_commun", "unlock": 0, "rate": 0.25},
	"longue_vue": {"name": "Longue-vue de cuivre", "rarity": "non_commun", "unlock": 2, "range": 0.25},
	"ambre": {"name": "Ambre fossile", "rarity": "non_commun", "unlock": 4, "effect": 0.3},
	# --- Rares : +40 % et un second bonus ---
	"scarabee_or": {"name": "Scarabée d'or", "rarity": "rare", "unlock": 0, "damage": 0.4, "range": 0.15},
	"sablier_quartz": {"name": "Sablier de quartz", "rarity": "rare", "unlock": 6, "rate": 0.4, "damage": 0.15},
	"oeil_faucon": {"name": "Œil de faucon", "rarity": "rare", "unlock": 8, "range": 0.4, "rate": 0.15},
	"cristal": {"name": "Cristal des glaces", "rarity": "rare", "unlock": 12, "effect": 0.6, "range": 0.15},
	"sceau": {"name": "Sceau de granit", "rarity": "rare", "unlock": 5, "seal": true, "range": 0.15,
		"short": "Murs à portée impossibles à creuser par les fouisseurs, +15 % de portée.",
		"desc": "Les murs à portée de la tour ne peuvent plus être creusés : les fouisseurs doivent faire le tour. +15 % de portée."},
	# --- Légendaires : gros bonus, mais il faut adapter son labyrinthe ---
	"lance": {"name": "Lance du Pharaon", "rarity": "legendaire", "unlock": 5, "damage_x": 4.0, "line": true,
		"short": "Dégâts x4, mais tir en ligne droite sur sa portée de base (E pour tourner).",
		"desc": "Dégâts x4. La tour ne vise plus autour d'elle : elle tire en ligne droite dans une direction (touche E pour tourner), sur autant de cases que sa portée de base, et touche tout ce qui est sur la ligne."},
	"couronne": {"name": "Couronne du Scarabée-Roi", "rarity": "legendaire", "unlock": 10, "damage_x": 3.0, "rate_x": 1.5, "fixed_range": 72.0,
		"short": "Dégâts x3 et cadence x1,5, mais portée de 1,5 case.",
		"desc": "Dégâts x3 et cadence x1,5, mais la portée tombe à 1,5 case : la tour doit être collée au chemin."},
	"coeur": {"name": "Cœur du Colosse gelé", "rarity": "legendaire", "unlock": 15, "rate_x": 3.0, "only_slowed": true,
		"short": "Cadence x3, mais ne vise que les ennemis ralentis.",
		"desc": "Cadence x3, mais la tour ne vise que les ennemis déjà ralentis. À combiner avec le Givre."},
}


static func get_relic(id: String) -> Dictionary:
	return DATA[id]


static func is_legendary(id: String) -> bool:
	return DATA[id]["rarity"] == "legendaire"


## Texte qui décrit l'effet d'une relique.
static func describe(id: String) -> String:
	var r: Dictionary = DATA[id]
	if r.has("desc"):
		return r["desc"]
	var parts := []
	var names := {"damage": "dégâts", "rate": "cadence", "range": "portée", "effect": "effets spéciaux"}
	for k in ["damage", "rate", "range", "effect"]:
		if r.has(k):
			parts.append("+%d %% %s" % [roundi(r[k] * 100), names[k]])
	return ", ".join(parts)


## Description courte (carnet) : le champ « short » s'il existe, sinon la description complète.
## Une relique légendaire garantie (boss tué) : on la tire parmi les légendaires débloquées.
## Si aucune n'est encore débloquée, on donne quand même la plus facile à débloquer.
static func draw_legendary(rng: RandomNumberGenerator, unlocked: Callable) -> String:
	var pool := []
	var easiest := ""
	for id in DATA:
		if DATA[id]["rarity"] != "legendaire":
			continue
		if unlocked.call(id):
			pool.append(id)
		if easiest == "" or int(DATA[id].get("unlock", 0)) < int(DATA[easiest].get("unlock", 0)):
			easiest = id
	if pool.is_empty():
		return easiest
	return pool[rng.randi_range(0, pool.size() - 1)]


static func describe_short(id: String) -> String:
	return DATA[id].get("short", describe(id))


## Chances des raretés de relique quand la stat Chance est au maximum.
## Entre 0 et le maximum, les chances glissent en ligne droite des valeurs de base vers celles-ci.
## (Celles des jokers sont dans jokers.gd.)
const MAX_LUCK_WEIGHTS := {"commun": 22.0, "non_commun": 50.0, "rare": 20.0, "legendaire": 8.0}


## Chances de chaque rareté avec la stat Chance (luck va de 0 à 1).
static func lucky_weights(base: Dictionary, luck: float, target: Dictionary = MAX_LUCK_WEIGHTS) -> Dictionary:
	var w := {}
	for rar in RARITIES:
		w[rar] = lerpf(float(base[rar]), float(target[rar]), clampf(luck, 0.0, 1.0))
	return w


## Tire une rareté parmi celles autorisées, selon les chances données.
static func roll_rarity(rng: RandomNumberGenerator, weights: Dictionary, allowed: Array) -> String:
	var total := 0.0
	for rar in allowed:
		total += weights[rar]
	var roll := rng.randf() * total
	for rar in allowed:
		roll -= weights[rar]
		if roll < 0.0:
			return rar
	return allowed[allowed.size() - 1]


## Tire une relique débloquée au hasard. min_rarity force une rareté minimale (élite, boss).
## luck = niveau de la stat Chance, de 0 à 1 (voir lucky_weights).
## max_rarity plafonne la rareté (boss qui s'est échappé : rare au maximum).
## Si aucune relique de la rareté tirée n'est débloquée, on descend d'une rareté.
static func draw(rng: RandomNumberGenerator, min_rarity := "commun", luck := 0.0, unlocked: Callable = Callable(), max_rarity := "legendaire") -> String:
	var top := RARITIES.find(max_rarity)
	var allowed := RARITIES.slice(RARITIES.find(min_rarity), top + 1)
	var index := RARITIES.find(roll_rarity(rng, lucky_weights(WEIGHTS, luck), allowed))
	while index >= 0:
		var pool := []
		for id in DATA:
			if DATA[id]["rarity"] == RARITIES[index] and (not unlocked.is_valid() or unlocked.call(id)):
				pool.append(id)
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
		index -= 1
	return "silex"
