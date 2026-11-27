class_name Jokers
extends RefCounted
## Les jokers : chacun change une règle du jeu. On en garde 5 au maximum.
## Comme les reliques, ils ont 4 raretés : commun, non commun, rare, légendaire.
## Les légendaires sont très forts, souvent avec une contrepartie.

const MAX_HELD := 5

const RARITIES := ["commun", "non_commun", "rare", "legendaire"]
const RARITY_NAMES := {"commun": "Commun", "non_commun": "Peu commun", "rare": "Rare", "legendaire": "Légendaire"}
## Chances de tirer chaque rareté pour une carte joker (sur 100).
const WEIGHTS := {"commun": 55, "non_commun": 30, "rare": 12, "legendaire": 3}
## Chances quand la stat Chance est au maximum (10 points).
const MAX_LUCK_WEIGHTS := {"commun": 25, "non_commun": 50, "rare": 20, "legendaire": 5}

## Réglages des jokers à effet chiffré (pour équilibrer facilement).
const BUTIN_GOLD := 0.3          # Butin de fouille : +30 % d'or pendant les vagues
const MEUTE_PER_TOWER := 0.1     # Esprit de meute : +10 % de cadence par autre tour du même type
const MEUTE_MAX := 0.5           # ... plafonné à +50 %
const MAUDIT_GOLD := 2.0         # Trésor maudit : or gagné x2
const MAUDIT_HP := 1.25          # ... mais ennemis +25 % de PV
const ARCHITECTE_FREE_WALLS := 20  # Architecte fou : 20 murs gratuits par niveau...
const ARCHITECTE_TOWER := 1.5    # ... mais tours +50 %

const DATA := {
	# --- Communs ---
	"macon": {"name": "Maçon", "rarity": "commun",
		"desc": "Chaque mur ou rocher collé à une tour lui donne +12 de portée."},
	"pillard": {"name": "Pillard", "rarity": "commun",
		"desc": "Chaque ennemi qui s'échappe vous rapporte 6 or."},
	"briques": {"name": "Briques creuses", "rarity": "commun",
		"desc": "Les murs ne coûtent plus que 1 or."},
	"prime": {"name": "Prime de chasse", "rarity": "commun",
		"desc": "+2 or pour chaque ennemi tué."},
	"fondations": {"name": "Fondations", "rarity": "commun",
		"desc": "Les tours coûtent 25 % moins cher."},
	"rempart": {"name": "Rempart", "rarity": "commun",
		"desc": "+2 vies au début de chaque niveau."},
	# --- Non communs ---
	"butin": {"name": "Butin de fouille", "rarity": "non_commun",
		"desc": "+30 % d'or gagné pendant les vagues (ennemis tués et bonus de fin de vague)."},
	"cul_de_sac": {"name": "Cul-de-sac", "rarity": "non_commun",
		"desc": "Une tour bloquée sur 3 côtés ou plus inflige double dégâts."},
	"detour": {"name": "Long détour", "rarity": "non_commun",
		"desc": "Au début de chaque vague, +1 or toutes les 3 cases du chemin."},
	"givre_eternel": {"name": "Givre éternel", "rarity": "non_commun",
		"desc": "Les ralentissements durent deux fois plus longtemps et sont plus forts."},
	"venin": {"name": "Venin glacé", "rarity": "non_commun",
		"desc": "Le poison fait double dégâts aux ennemis ralentis."},
	"artilleur": {"name": "Artilleur", "rarity": "non_commun",
		"desc": "Les explosions du Mortier sont 50 % plus larges."},
	"ancetres": {"name": "Totems ancestraux", "rarity": "non_commun",
		"desc": "Les bonus de plusieurs Totems se cumulent."},
	# --- Rares ---
	"echo": {"name": "Écho", "rarity": "rare",
		"desc": "Les tirs d'Arbalète et de Baliste rebondissent sur un 2e ennemi (60 %)."},
	"fiole": {"name": "Fiole instable", "rarity": "rare",
		"desc": "Un ennemi empoisonné qui meurt explose et blesse ses voisins."},
	"sablier": {"name": "Sablier ancien", "rarity": "rare",
		"desc": "Pendant la première vague de chaque niveau, les ennemis sont 30 % plus lents."},
	"ecrin": {"name": "Écrin double", "rarity": "rare",
		"desc": "Chaque tour peut porter 2 reliques au lieu d'une (toujours une seule légendaire)."},
	# --- Légendaires ---
	"meute": {"name": "Esprit de meute", "rarity": "legendaire",
		"desc": "Chaque tour gagne +10 % de cadence par autre tour du même type posée (max +50 %)."},
	"maudit": {"name": "Trésor maudit", "rarity": "legendaire",
		"desc": "Tout l'or gagné pendant les vagues est doublé, mais les ennemis ont 25 % de PV en plus."},
	"architecte": {"name": "Architecte fou", "rarity": "legendaire",
		"desc": "Les 20 premiers murs de chaque niveau sont gratuits, mais les tours coûtent 50 % plus cher."},
}


static func get_joker(id: String) -> Dictionary:
	return DATA[id]


static func rarity_of(id: String) -> String:
	return DATA[id]["rarity"]


## Couleur d'un joker : la même échelle que les reliques.
static func color_of(id: String) -> Color:
	return Relics.RARITY_COLORS[rarity_of(id)]


## Tire 3 jokers différents que le joueur n'a pas encore.
## rare_slots = nombre de cartes qui seront au moins rares si possible (élite : 1, boss : 2).
## luck = niveau de la stat Chance, de 0 à 1 (voir Relics.lucky_weights).
## Si plus aucun joker de la rareté tirée n'est disponible, on prend la rareté la plus proche.
static func draw_choices(rng: RandomNumberGenerator, held: Array, rare_slots: int, luck := 0.0) -> Array[String]:
	var pools := {}
	for rar in RARITIES:
		pools[rar] = []
	for id in DATA:
		if not id in held:
			pools[DATA[id]["rarity"]].append(id)
	var weights := Relics.lucky_weights(WEIGHTS, luck, MAX_LUCK_WEIGHTS)
	var result: Array[String] = []
	for i in 3:
		var allowed: Array = RARITIES.slice(2) if i < rare_slots else RARITIES
		var index := RARITIES.find(Relics.roll_rarity(rng, weights, allowed))
		var pick := ""
		# on cherche dans la rareté tirée, puis on s'en éloigne petit à petit
		for d in RARITIES.size():
			for k in [index - d, index + d]:
				if pick == "" and k >= 0 and k < RARITIES.size() and not pools[RARITIES[k]].is_empty():
					var pool: Array = pools[RARITIES[k]]
					pick = pool[rng.randi_range(0, pool.size() - 1)]
					pool.erase(pick)
		if pick == "":
			break
		result.append(pick)
	return result

