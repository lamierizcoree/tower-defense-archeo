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

## Nombre de vagues selon le type de niveau (5 partout : demande de Lmz, le jeu était trop facile).
const WAVE_COUNT := {"combat": 5, "elite": 5, "boss": 5, "fouille": 5}

## Réglages de la difficulté des vagues (à ajuster en jouant).
const BASE_COUNT := 7            # ennemis dans la 1re vague du 1er niveau
const COUNT_PER_LEVEL := 1       # ennemis en plus par niveau de l'expédition
const COUNT_PER_WAVE := 3        # ennemis en plus à chaque vague du niveau
const HP_PER_LEVEL := 0.22       # PV en plus par niveau de l'expédition (+22 %)
const HP_PER_WAVE := 0.12        # PV en plus à chaque vague du niveau (+12 %)


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
		var count := BASE_COUNT + difficulty * COUNT_PER_LEVEL + w * COUNT_PER_WAVE
		if type == "elite":
			count = int(count * 1.3)
		# Les ennemis spéciaux arrivent au fil des vagues : les dernières vagues d'un niveau
		# ressemblent aux premières vagues des niveaux suivants.
		var level := difficulty + w / 2
		var fast := int(count * float(biome["fast_share"]))
		var diggers := (1 + level / 2) if (biome["diggers"] and level >= 1) else 0
		var tanks := 0
		if level >= 2:
			tanks = (level - 1) / 2
		if type == "elite":
			tanks += 1
		if biome["id"] == "glace" and w >= 1:
			tanks += 1
		var jars := (1 + level / 3) if level >= 1 else 0
		var flyers := (1 + level / 3) if level >= 2 else 0
		var healers := 0
		if level >= 3:
			healers = 1 + (1 if level >= 7 else 0) + (1 if type == "elite" else 0)
		var saboteurs := (1 + (level - 4) / 2) if level >= 4 else 0
		var normal := maxi(2, count - fast - diggers - tanks - jars - flyers - healers - saboteurs)

		var list: Array[String] = []
		for i in normal:
			list.append("eclaireur")
		for i in fast:
			list.append("rapide")
		for i in diggers:
			list.append("fouisseur")
		for i in tanks:
			list.append("colosse")
		for i in jars:
			list.append("jarre")
		for i in flyers:
			list.append("ibis")
		for i in healers:
			list.append("embaumeur")
		for i in saboteurs:
			list.append("pilleur")
		_shuffle(rng, list)
		# Élites (étoile devant le type) dans les dernières vagues : 1 à la 4e, plus à la 5e
		var elites := 0
		if w == n - 2:
			elites = 1 if difficulty >= 2 else 0
		elif w == n - 1:
			elites = 1 + difficulty / 3 + (1 if type == "elite" else 0)
		for k in mini(elites, list.size()):
			list[k] = "*" + list[k]
		_shuffle(rng, list)
		if type == "boss" and w == n - 1:
			list.append(biome["boss"])

		var hp_mult := (1.0 + HP_PER_LEVEL * difficulty + HP_PER_WAVE * w) * (1.25 if type == "elite" else 1.0)
		waves.append({"enemies": list, "hp_mult": hp_mult})
	return waves


static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
