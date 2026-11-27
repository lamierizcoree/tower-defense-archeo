class_name Relics
extends RefCounted
## Les reliques : des artefacts déterrés qu'on place dans les emplacements des tours.
## On les gagne dans les récompenses. Pendant un niveau, on les pose dans les tours
## avec la barre de reliques ; elles reviennent dans l'inventaire au niveau suivant.
##
## Bonus en pourcentage (0.15 = +15 %) :
##   damage : dégâts      rate : cadence de tir      range : portée
##   effect : effets spéciaux (ralentissement, poison, rayon d'explosion, bonus du Totem)
## Bonus des légendaires (un gros bonus, mais une contrainte) :
##   damage_x / rate_x : multiplicateurs
##   line : la tour tire en ligne droite dans une direction, sur autant de cases que sa portée de base
##   fixed_range : portée imposée, en pixels
##   only_slowed : la tour ne vise que les ennemis ralentis

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
	"silex": {"name": "Pointe de silex", "rarity": "commun", "damage": 0.15},
	"plume": {"name": "Plume de vautour", "rarity": "commun", "rate": 0.15},
	"lentille": {"name": "Lentille fêlée", "rarity": "commun", "range": 0.15},
	# --- Peu communes : +25 % ---
	"amulette": {"name": "Amulette de bronze", "rarity": "non_commun", "damage": 0.25},
	"rouage": {"name": "Rouage ancien", "rarity": "non_commun", "rate": 0.25},
	"longue_vue": {"name": "Longue-vue de cuivre", "rarity": "non_commun", "range": 0.25},
	"ambre": {"name": "Ambre fossile", "rarity": "non_commun", "effect": 0.3},
	# --- Rares : +40 % et un second bonus ---
	"scarabee_or": {"name": "Scarabée d'or", "rarity": "rare", "damage": 0.4, "range": 0.15},
	"sablier_quartz": {"name": "Sablier de quartz", "rarity": "rare", "rate": 0.4, "damage": 0.15},
	"oeil_faucon": {"name": "Œil de faucon", "rarity": "rare", "range": 0.4, "rate": 0.15},
	"cristal": {"name": "Cristal des glaces", "rarity": "rare", "effect": 0.6, "range": 0.15},
	# --- Légendaires : gros bonus, mais il faut adapter son labyrinthe ---
	"lance": {"name": "Lance du Pharaon", "rarity": "legendaire", "damage_x": 4.0, "line": true,
		"desc": "Dégâts x4. La tour ne vise plus autour d'elle : elle tire en ligne droite dans une direction (touche E pour tourner), sur autant de cases que sa portée de base, et touche tout ce qui est sur la ligne."},
	"couronne": {"name": "Couronne du Scarabée-Roi", "rarity": "legendaire", "damage_x": 3.0, "rate_x": 1.5, "fixed_range": 72.0,
		"desc": "Dégâts x3 et cadence x1,5, mais la portée tombe à 1,5 case : la tour doit être collée au chemin."},
	"coeur": {"name": "Cœur du Colosse gelé", "rarity": "legendaire", "rate_x": 3.0, "only_slowed": true,
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


## Tire une relique au hasard. min_rarity force une rareté minimale (élite, boss).
static func draw(rng: RandomNumberGenerator, min_rarity := "commun") -> String:
	var allowed := RARITIES.slice(RARITIES.find(min_rarity))
	var total := 0
	for rar in allowed:
		total += WEIGHTS[rar]
	var roll := rng.randi_range(1, total)
	var rarity: String = allowed[0]
	for rar in allowed:
		roll -= WEIGHTS[rar]
		if roll <= 0:
			rarity = rar
			break
	var pool := []
	for id in DATA:
		if DATA[id]["rarity"] == rarity:
			pool.append(id)
	return pool[rng.randi_range(0, pool.size() - 1)]
