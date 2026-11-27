class_name Levels
extends RefCounted
## Les plans des niveaux et la création des vagues.
##
## Légende des plans (20 colonnes x 12 lignes) :
##   .  case libre        #  rocher (bloque, on ne construit pas dessus)
##   ~  glace (on peut construire, les ennemis y glissent deux fois plus vite)
##   S  entrée des ennemis (il peut y en avoir plusieurs)
##   G  sortie que les ennemis veulent atteindre

const LAYOUTS := {
	# ---------------- Désert ----------------
	"d1": {"name": "Le campement", "rows": [
		"....................",
		"....................",
		".....#........#.....",
		"....................",
		".........##.........",
		"S..................G",
		"....................",
		".........##.........",
		"....................",
		".....#........#.....",
		"....................",
		"....................",
	]},
	"d2": {"name": "Les colonnes", "rows": [
		"....................",
		"...#....#....#......",
		"...#....#....#......",
		"....................",
		"......#....#....#...",
		"S.....#....#....#...",
		"......#....#....#..G",
		"....................",
		"...#....#....#......",
		"...#....#....#......",
		"....................",
		"....................",
	]},
	"d3": {"name": "Le canyon", "rows": [
		"S...................",
		"....................",
		".....######.........",
		"...........#........",
		"....##......#.......",
		"......#......#......",
		".......#......##....",
		"........#...........",
		".........######.....",
		"....................",
		"....................",
		"...................G",
	]},
	"d4": {"name": "Les deux tranchées", "rows": [
		"S...................",
		"....................",
		"....#########.......",
		"....................",
		".........#..........",
		".........#.........G",
		".........#..........",
		"....................",
		"....#########.......",
		"....................",
		"....................",
		"S...................",
	]},
	"d5": {"name": "L'oasis asséchée", "rows": [
		"S...................",
		"....................",
		"....................",
		".......##..##.......",
		"......#......#......",
		".........G..........",
		"......#......#......",
		".......##..##.......",
		"....................",
		"....................",
		"....................",
		"...................S",
	]},
	"d_boss": {"name": "La chambre du Scarabée-Roi", "rows": [
		".........S..........",
		"....................",
		"..##....#..#....##..",
		"....................",
		"....#..........#....",
		".......##..##.......",
		"....#..........#....",
		"....................",
		"..##....#..#....##..",
		"....................",
		"....................",
		".........G..........",
	]},
	# ---------------- Glace ----------------
	"g1": {"name": "Le lac gelé", "rows": [
		"....................",
		"....................",
		"....~~~~~~~~~~~.....",
		"...~~~~~~~~~~~~~....",
		"...~~~~~~~~~~~~~....",
		"S..~~~~~~~~~~~~~...G",
		"...~~~~~~~~~~~~~....",
		"...~~~~~~~~~~~~~....",
		"....~~~~~~~~~~~.....",
		"....................",
		"....................",
		"....................",
	]},
	"g2": {"name": "Les crevasses", "rows": [
		"S...................",
		"....................",
		"#######.....########",
		"~~~~~~~~~~~~~~~~~~~~",
		"....................",
		".....##########.....",
		"....................",
		"~~~~~~~~~~~~~~~~~~~~",
		"########.....#######",
		"....................",
		"....................",
		"...................G",
	]},
	"g3": {"name": "La banquise", "rows": [
		"....~~......~~......",
		"..~~~~....~~~~~~....",
		"..~~..#.....~~....#.",
		"......#..~~.........",
		"~~....#..~~~~...~~..",
		"G........~~~....~~.S",
		"~~...~~.........~~..",
		"....~~~~...#........",
		"....~~.....#..~~~...",
		".#.........#..~~~~..",
		"..~~~...........~~..",
		"..~~~~..............",
	]},
	"g4": {"name": "Le col", "rows": [
		"####################",
		"####################",
		"####......####......",
		"....................",
		".~~~~~~~~~~~~~~~~~~.",
		"S~~~~~~~~~~~~~~~~~~G",
		".~~~~~~~~~~~~~~~~~~.",
		"....................",
		"####......####......",
		"####################",
		"####################",
		"####################",
	]},
	"g5": {"name": "Les deux glaciers", "rows": [
		"...................S",
		".......~~~~~........",
		"......~~~~~~~.......",
		"....#.........#.....",
		"....#.........#.....",
		"G...#...###...#.....",
		"....#.........#.....",
		"....#.........#.....",
		"......~~~~~~~.......",
		".......~~~~~........",
		"....................",
		"...................S",
	]},
	"g_boss": {"name": "Le tombeau du Colosse gelé", "rows": [
		"S..................S",
		".~~..............~~.",
		".~~....#....#....~~.",
		".......#....#.......",
		"...~~~~~....~~~~~...",
		"...~..........~.....",
		"...~~~~~....~~~~~...",
		".......#....#.......",
		".~~....#....#....~~.",
		".~~..............~~.",
		"....................",
		".........G..........",
	]},
}

## Les niveaux de chaque biome (hors boss), dans l'ordre de la liste Biomes.LIST.
const POOLS := [
	["d1", "d2", "d3", "d4", "d5"],
	["g1", "g2", "g3", "g4", "g5"],
]
const BOSS_LAYOUTS := ["d_boss", "g_boss"]

## Nombre de vagues selon le type de niveau.
const WAVE_COUNT := {"combat": 2, "elite": 3, "boss": 3}


static func get_layout(id: String) -> Dictionary:
	return LAYOUTS[id]


## Crée les vagues d'un niveau. Chaque vague est un dictionnaire :
##   enemies : liste des types d'ennemis, dans l'ordre d'apparition
##   hp_mult : multiplicateur de points de vie
static func make_waves(rng: RandomNumberGenerator, biome_index: int, floor_index: int, type: String) -> Array:
	var biome := Biomes.get_biome(biome_index)
	var difficulty := biome_index * 5 + floor_index   # de 0 à 9
	var waves := []
	var n: int = WAVE_COUNT[type]
	for w in n:
		var count := 6 + difficulty + w * 2
		if type == "elite":
			count = int(count * 1.3)
		var fast := int(count * float(biome["fast_share"]))
		var diggers := (1 + difficulty / 2) if (biome["diggers"] and difficulty >= 1) else 0
		var tanks := 0
		if difficulty >= 2:
			tanks = (difficulty - 1) / 2
		if type == "elite":
			tanks += 1
		if biome["id"] == "glace":
			tanks += 1
		var normal := maxi(2, count - fast - diggers - tanks)

		var list: Array[String] = []
		for i in normal:
			list.append("eclaireur")
		for i in fast:
			list.append("rapide")
		for i in diggers:
			list.append("fouisseur")
		for i in tanks:
			list.append("colosse")
		_shuffle(rng, list)
		if type == "boss" and w == n - 1:
			list.append(biome["boss"])

		var hp_mult := (1.0 + 0.2 * difficulty + 0.08 * w) * (1.25 if type == "elite" else 1.0)
		waves.append({"enemies": list, "hp_mult": hp_mult})
	return waves


static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
