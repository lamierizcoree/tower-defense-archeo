class_name TowerTypes
extends RefCounted
## Les 6 tours du jeu et leurs réglages. Pour équilibrer, il suffit de changer ces chiffres.
##
## Champs possibles :
##   name, cost, range (pixels), color, key (touche du clavier), desc
##   attack : "single" (un ennemi), "splash" (zone autour de la cible),
##            "aura" (tous les ennemis à portée), "poison", "support" (n'attaque pas)
##   damage, delay (secondes entre deux tirs)
##   splash_radius, min_range (mortier)
##   slow (vitesse multipliée par ce nombre), slow_time (givre)
##   poison_dps, poison_time (alambic)
##   buff (bonus de cadence donné aux tours voisines, totem)
##   specs : les deux spécialisations proposées au niveau 3 (voies "a" et "b").
##     Clés possibles : rate_x, damage_x, range_x, radius_x, poison_x, buff_x (multiplicateurs),
##     strongest (vise l'ennemi qui a le plus de PV), harpoon [ralentissement, durée],
##     pierce (traverse), fire [dégâts/s, durée], deep_slow (ralentissement), cloud (rayon),
##     acid (dégâts subis en plus par les empoisonnés), rage (bonus de dégâts aux voisines).

## Niveau 2 : bonus sur les dégâts et les effets, et sur la portée.
const TIER2_POWER := 1.3
const TIER2_RANGE := 1.1
## Prix des améliorations, en part du prix de la tour.
const TIER2_COST := 0.6
const TIER3_COST := 1.0

const ORDER := ["arbalete", "baliste", "mortier", "givre", "alambic", "totem"]

const DATA := {
	"arbalete": {
		"name": "Arbalète", "key": KEY_2, "cost": 15, "range": 150.0,
		"attack": "single", "damage": 10.0, "delay": 0.6,
		"color": Color("3f7fd1"),
		"desc": "Tir rapide sur un ennemi",
		"specs": {
			"a": {"name": "Rafale", "desc": "Cadence x2", "rate_x": 2.0},
			"b": {"name": "Tireur d'élite", "desc": "Dégâts x1,6, portée +40 %, vise le plus résistant",
				"damage_x": 1.6, "range_x": 1.4, "strongest": true},
		},
	},
	"baliste": {
		"name": "Baliste", "key": KEY_3, "cost": 30, "range": 230.0,
		"attack": "single", "damage": 45.0, "delay": 2.0,
		"color": Color("5b5f66"),
		"desc": "Gros dégâts, grande portée, lente",
		"specs": {
			"a": {"name": "Harpon", "desc": "Dégâts x1,3, ralentit la cible de 50 % pendant 1,5 s",
				"damage_x": 1.3, "harpoon": [0.5, 1.5]},
			"b": {"name": "Perce-rangs", "desc": "Le carreau traverse tous les ennemis sur sa trajectoire", "pierce": true},
		},
	},
	"mortier": {
		"name": "Mortier", "key": KEY_4, "cost": 35, "range": 200.0, "min_range": 60.0,
		"attack": "splash", "damage": 16.0, "delay": 1.8, "splash_radius": 60.0,
		"color": Color("d9822b"),
		"desc": "Dégâts de zone, ne tire pas de près",
		"specs": {
			"a": {"name": "Obus incendiaires", "desc": "L'explosion brûle : 6 dégâts/s pendant 3 s", "fire": [6.0, 3.0]},
			"b": {"name": "Grand calibre", "desc": "Dégâts x1,5, explosion 50 % plus large, cadence x0,8",
				"damage_x": 1.5, "radius_x": 1.5, "rate_x": 0.8},
		},
	},
	"givre": {
		"name": "Givre", "key": KEY_5, "cost": 20, "range": 110.0,
		"attack": "aura", "damage": 2.0, "delay": 0.5, "slow": 0.5, "slow_time": 1.2,
		"color": Color("7fd6e8"),
		"desc": "Ralentit tout ce qui est à portée",
		"specs": {
			"a": {"name": "Blizzard", "desc": "Portée x1,4", "range_x": 1.4},
			"b": {"name": "Gel profond", "desc": "Ralentit de 70 % et dégâts x3", "deep_slow": 0.3, "damage_x": 3.0},
		},
	},
	"alambic": {
		"name": "Alambic", "key": KEY_6, "cost": 25, "range": 140.0,
		"attack": "poison", "damage": 0.0, "delay": 1.0, "poison_dps": 8.0, "poison_time": 4.0,
		"color": Color("6aa84f"),
		"desc": "Empoisonne, vise les ennemis sains",
		"specs": {
			"a": {"name": "Nuage toxique", "desc": "Empoisonne aussi les ennemis autour de la cible", "cloud": 55.0},
			"b": {"name": "Acide", "desc": "Poison x1,5 ; les empoisonnés subissent +20 % de dégâts",
				"poison_x": 1.5, "acid": 0.2},
		},
	},
	"totem": {
		"name": "Totem", "key": KEY_7, "cost": 30, "range": 110.0,
		"attack": "support", "buff": 0.3,
		"color": Color("b8860b"),
		"desc": "Tours voisines +30 % de cadence",
		"specs": {
			"a": {"name": "Tambours de guerre", "desc": "Bonus de cadence x1,7", "buff_x": 1.7},
			"b": {"name": "Totem de rage", "desc": "Tours à portée : +25 % de dégâts en plus", "rage": 0.25},
		},
	},
}


static func get_type(id: String) -> Dictionary:
	return DATA[id]
