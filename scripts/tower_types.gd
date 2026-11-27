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

const ORDER := ["arbalete", "baliste", "mortier", "givre", "alambic", "totem"]

const DATA := {
	"arbalete": {
		"name": "Arbalète", "key": KEY_2, "cost": 15, "range": 150.0,
		"attack": "single", "damage": 10.0, "delay": 0.6,
		"color": Color("3f7fd1"),
		"desc": "Tir rapide sur un ennemi",
	},
	"baliste": {
		"name": "Baliste", "key": KEY_3, "cost": 30, "range": 230.0,
		"attack": "single", "damage": 45.0, "delay": 2.0,
		"color": Color("5b5f66"),
		"desc": "Gros dégâts, grande portée, lente",
	},
	"mortier": {
		"name": "Mortier", "key": KEY_4, "cost": 35, "range": 200.0, "min_range": 60.0,
		"attack": "splash", "damage": 16.0, "delay": 1.8, "splash_radius": 60.0,
		"color": Color("d9822b"),
		"desc": "Dégâts de zone, ne tire pas de près",
	},
	"givre": {
		"name": "Givre", "key": KEY_5, "cost": 20, "range": 110.0,
		"attack": "aura", "damage": 2.0, "delay": 0.5, "slow": 0.5, "slow_time": 1.2,
		"color": Color("7fd6e8"),
		"desc": "Ralentit tout ce qui est à portée",
	},
	"alambic": {
		"name": "Alambic", "key": KEY_6, "cost": 25, "range": 140.0,
		"attack": "poison", "damage": 0.0, "delay": 1.0, "poison_dps": 8.0, "poison_time": 4.0,
		"color": Color("6aa84f"),
		"desc": "Empoisonne, vise les ennemis sains",
	},
	"totem": {
		"name": "Totem", "key": KEY_7, "cost": 30, "range": 110.0,
		"attack": "support", "buff": 0.3,
		"color": Color("b8860b"),
		"desc": "Tours voisines +30 % de cadence",
	},
}


static func get_type(id: String) -> Dictionary:
	return DATA[id]
