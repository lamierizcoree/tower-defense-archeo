class_name Difficulty
extends RefCounted
## Les niveaux de difficulté, débloqués en réussissant des expéditions.
## Réussir une expédition au niveau le plus haut débloqué ouvre le suivant.
## Chaque niveau ajoute une nouvelle règle qui s'ajoute à celles des niveaux précédents :
## au niveau 3, les règles 1, 2 et 3 sont toutes actives.
## En échange, le score (donc les points d'amélioration) est plus élevé.

const SCORE_PER_LEVEL := 0.15   # +15 % de score par niveau

## Réglages des règles (pour équilibrer facilement).
const ELITE_SHARE := 0.1        # Élites errants : 1 ennemi sur 10 devient élite
const ELITE_HP := 2.5           # ... avec 2,5 fois plus de PV
const SPEED_BONUS := 1.1        # Vents contraires : ennemis +10 % de vitesse
const WALL_COST := 3            # Fouilles coûteuses : un mur coûte 3 or au lieu de 2
const RIVALRY_FROM := 3         # Rivalité : à partir de la 3e tour identique...
const RIVALRY_RATE := 0.8       # ... ces tours tirent 20 % moins vite
const START_GOLD := 0.75        # Bourse maigre : -25 % d'or au début de chaque niveau
const WALL_LIMIT := 20          # Carrière épuisée : 20 murs au maximum par niveau
const BOSS_ESCORT := 2          # Garde rapprochée : le boss arrive avec 2 colosses élites
const REGEN := 0.02             # Chair maudite : les ennemis non empoisonnés regagnent 2 % de PV par seconde
const LIVES_MALUS := 8          # Expédition de trop : 8 vies de moins au départ

## Une règle par niveau, dans l'ordre (le niveau 1 active la première).
const RULES := [
	{"id": "elites", "name": "Élites errants",
		"desc": "1 ennemi sur 10 est un élite : PV x2,5, coûte 1 vie de plus, rapporte plus."},
	{"id": "vitesse", "name": "Vents contraires",
		"desc": "Tous les ennemis vont 10 % plus vite."},
	{"id": "murs_chers", "name": "Fouilles coûteuses",
		"desc": "Les murs coûtent 3 or au lieu de 2."},
	{"id": "rivalite", "name": "Rivalité des ateliers",
		"desc": "À partir de 3 tours identiques, ces tours tirent 20 % moins vite."},
	{"id": "bourse", "name": "Bourse maigre",
		"desc": "25 % d'or en moins au début de chaque niveau."},
	{"id": "carriere", "name": "Carrière épuisée",
		"desc": "20 murs au maximum par niveau."},
	{"id": "escorte", "name": "Garde rapprochée",
		"desc": "Le boss arrive avec 2 colosses élites."},
	{"id": "maigre_butin", "name": "Butin pillé",
		"desc": "Chaque ennemi tué rapporte 1 or de moins (au moins 1)."},
	{"id": "regen", "name": "Chair maudite",
		"desc": "Les ennemis regagnent 2 % de leurs PV par seconde, sauf s'ils sont empoisonnés."},
	{"id": "vies", "name": "Expédition de trop",
		"desc": "8 vies de moins au départ de l'expédition."},
]

const MAX := 10   # = nombre de règles


## La règle est-elle active à ce niveau de difficulté ?
static func has(level: int, rule_id: String) -> bool:
	for i in mini(level, RULES.size()):
		if RULES[i]["id"] == rule_id:
			return true
	return false


## Raccourci pour l'expédition en cours.
static func active(rule_id: String) -> bool:
	return has(Run.difficulty, rule_id)


## Multiplicateur de score à la fin de l'expédition.
static func score_mult(level: int) -> float:
	return 1.0 + SCORE_PER_LEVEL * level


static func name_of(level: int) -> String:
	return "Normale" if level == 0 else "Difficulté %d" % level


## La règle ajoutée par ce niveau.
static func rule_of(level: int) -> Dictionary:
	return RULES[level - 1]


static func describe(level: int) -> String:
	if level == 0:
		return "La difficulté de base."
	var r := rule_of(level)
	return "%s : %s" % [r["name"], r["desc"]]
