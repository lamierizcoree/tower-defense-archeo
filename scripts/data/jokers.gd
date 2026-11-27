class_name Jokers
extends RefCounted
## Les jokers : chacun change une règle du jeu. On en garde 5 au maximum.

const MAX_HELD := 5
const RARE_CHANCE := 0.12

const DATA := {
	# --- Communs ---
	"macon": {"name": "Maçon", "rare": false,
		"desc": "Chaque mur ou rocher collé à une tour lui donne +12 de portée."},
	"cul_de_sac": {"name": "Cul-de-sac", "rare": false,
		"desc": "Une tour bloquée sur 3 côtés ou plus inflige double dégâts."},
	"pillard": {"name": "Pillard", "rare": false,
		"desc": "Chaque ennemi qui s'échappe vous rapporte 6 or."},
	"briques": {"name": "Briques creuses", "rare": false,
		"desc": "Les murs ne coûtent plus que 1 or."},
	"prime": {"name": "Prime de chasse", "rare": false,
		"desc": "+2 or pour chaque ennemi tué."},
	"detour": {"name": "Long détour", "rare": false,
		"desc": "Au début de chaque vague, +1 or toutes les 3 cases du chemin."},
	"givre_eternel": {"name": "Givre éternel", "rare": false,
		"desc": "Les ralentissements durent deux fois plus longtemps et sont plus forts."},
	"venin": {"name": "Venin glacé", "rare": false,
		"desc": "Le poison fait double dégâts aux ennemis ralentis."},
	"artilleur": {"name": "Artilleur", "rare": false,
		"desc": "Les explosions du Mortier sont 50 % plus larges."},
	"ancetres": {"name": "Totems ancestraux", "rare": false,
		"desc": "Les bonus de plusieurs Totems se cumulent."},
	"fondations": {"name": "Fondations", "rare": false,
		"desc": "Les tours coûtent 25 % moins cher."},
	"rempart": {"name": "Rempart", "rare": false,
		"desc": "+2 vies au début de chaque niveau."},
	# --- Rares ---
	"echo": {"name": "Écho", "rare": true,
		"desc": "Les tirs d'Arbalète et de Baliste rebondissent sur un 2e ennemi (60 %)."},
	"fiole": {"name": "Fiole instable", "rare": true,
		"desc": "Un ennemi empoisonné qui meurt explose et blesse ses voisins."},
	"sablier": {"name": "Sablier ancien", "rare": true,
		"desc": "Pendant la première vague de chaque niveau, les ennemis sont 30 % plus lents."},
}


static func get_joker(id: String) -> Dictionary:
	return DATA[id]


## Tire 3 jokers différents que le joueur n'a pas encore.
## rare_slots = nombre de cartes qui seront rares si possible (élite : 1, boss : 3).
static func draw_choices(rng: RandomNumberGenerator, held: Array, rare_slots: int, luck := 0.0) -> Array[String]:
	var commons: Array[String] = []
	var rares: Array[String] = []
	for id in DATA:
		if id in held:
			continue
		if DATA[id]["rare"]:
			rares.append(id)
		else:
			commons.append(id)
	var result: Array[String] = []
	for i in 3:
		var want_rare := i < rare_slots or rng.randf() < RARE_CHANCE + luck
		var pool := rares if (want_rare and not rares.is_empty()) else commons
		if pool.is_empty():
			pool = rares if not rares.is_empty() else commons
		if pool.is_empty():
			break
		var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		result.append(pick)
	return result
