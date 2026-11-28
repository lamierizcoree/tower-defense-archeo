class_name MapGen
extends RefCounted
## Crée la carte à embranchements d'un biome.
## La carte est une liste d'étages. Chaque étage est une liste de nœuds :
##   type   : "combat", "elite", "boss", "fouille" (combat avec une mission),
##            "event" (événement), "shop" (marchand) ou "camp" (feu de camp)
##   layout : identifiant du plan (voir levels.gd)
##   links  : index des nœuds de l'étage suivant auxquels ce nœud mène
##   pos    : hauteur du nœud à l'écran, entre 0 et 1

const FLOORS := 5            # 4 étages de niveaux + le boss
## Chances de chaque type de nœud aux étages du milieu (le reste est du combat).
const NODE_CHANCES := {"elite": 0.28, "event": 0.16, "fouille": 0.1, "shop": 0.08, "camp": 0.06}


static func generate(rng: RandomNumberGenerator, biome_index: int) -> Array:
	var pool: Array = Levels.POOLS[biome_index]
	var floors := []
	var previous_layouts: Array = []
	var used := {}
	for f in FLOORS:
		var nodes := []
		if f == FLOORS - 1:
			nodes.append(_node("boss", Levels.BOSS_LAYOUTS[biome_index], 0.5))
		else:
			var count := 2 if f == 0 else rng.randi_range(2, 3)
			var layouts := _pick_layouts(rng, pool, previous_layouts, count, used)
			for i in count:
				var type := "combat" if f == 0 else _roll_type(rng)
				nodes.append(_node(type, layouts[i], (i + 0.5) / count))
			# Juste avant le boss, au moins un marchand ou un feu de camp
			if f == FLOORS - 2:
				var has_rest := false
				for n in nodes:
					has_rest = has_rest or n["type"] in ["shop", "camp"]
				if not has_rest:
					nodes[rng.randi_range(0, nodes.size() - 1)]["type"] = "shop" if rng.randf() < 0.5 else "camp"
			previous_layouts = layouts
		floors.append(nodes)
	_link(rng, floors)
	return floors


static func _roll_type(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for type in NODE_CHANCES:
		roll -= NODE_CHANCES[type]
		if roll < 0.0:
			return type
	return "combat"


## Vrai pour les nœuds où l'on se bat.
static func is_fight(type: String) -> bool:
	return type in ["combat", "elite", "boss", "fouille"]


static func _node(type: String, layout: String, pos: float) -> Dictionary:
	return {"type": type, "layout": layout, "links": [], "pos": pos}


## Choisit des plans différents pour un étage : d'abord ceux qui ne sont pas à l'étage
## précédent, et parmi eux ceux qui ont le moins servi, pour varier les parcours.
static func _pick_layouts(rng: RandomNumberGenerator, pool: Array, avoid: Array, count: int, used: Dictionary) -> Array:
	var candidates := pool.duplicate()
	Levels._shuffle(rng, candidates)
	candidates.sort_custom(func(a, b):
		var ka := (100 if a in avoid else 0) + int(used.get(a, 0))
		var kb := (100 if b in avoid else 0) + int(used.get(b, 0))
		return ka < kb)
	var result := candidates.slice(0, count)
	for id in result:
		used[id] = int(used.get(id, 0)) + 1
	return result


## Relie chaque étage au suivant : chaque nœud a au moins une sortie,
## chaque nœud suivant a au moins une entrée, et les liens ne se croisent pas.
static func _link(rng: RandomNumberGenerator, floors: Array) -> void:
	for f in floors.size() - 1:
		var here: Array = floors[f]
		var next: Array = floors[f + 1]
		for i in here.size():
			var j := _closest(next, here[i]["pos"])
			_add_link(here[i], j)
		for j in next.size():
			var i := _closest(here, next[j]["pos"])
			_add_link(here[i], j)
		# Un embranchement en plus, de temps en temps, vers un voisin direct.
		for i in here.size():
			if rng.randf() < 0.4:
				var j := _closest(next, here[i]["pos"]) + (1 if rng.randf() < 0.5 else -1)
				if j >= 0 and j < next.size() and not _crosses(here, i, j):
					_add_link(here[i], j)


static func _closest(nodes: Array, pos: float) -> int:
	var best := 0
	for k in nodes.size():
		if absf(nodes[k]["pos"] - pos) < absf(nodes[best]["pos"] - pos):
			best = k
	return best


static func _add_link(node: Dictionary, j: int) -> void:
	if not j in node["links"]:
		node["links"].append(j)
		node["links"].sort()


static func _crosses(here: Array, i: int, j: int) -> bool:
	for k in here.size():
		for l in here[k]["links"]:
			if (k < i and l > j) or (k > i and l < j):
				return true
	return false
