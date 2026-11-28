class_name Upgrades
extends RefCounted
## Les améliorations permanentes (méta-progression), comme dans le document de concept.
## Le score de chaque expédition s'ajoute au score cumulé, qui donne des points d'amélioration.
## Chaque point coûte plus cher que le précédent : les 4 premiers coûtent 1 000 de score chacun
## (environ une expédition), puis chaque point coûte 250 de plus que le précédent.
## On répartit ses points librement entre les catégories, et on peut les redistribuer à tout moment
## au camp de base. Au plus 50 points peuvent être utilisés, alors que les catégories en
## accepteraient 60 : il faut faire des choix.

const FIRST_POINT_COST := 1000   # prix des premiers points, en score cumulé
const CHEAP_POINTS := 4          # nombre de points au prix de départ
const COST_STEP := 250           # supplément pour chaque point suivant
const CAP := 50
const MAX_PER_CATEGORY := 10

const ORDER := ["puissance", "cadence", "economie", "rempart", "chance", "preparation", "forge"]

const DATA := {
	"puissance": {"name": "Puissance", "desc": "+1 % de dégâts pour toutes les tours"},
	"cadence": {"name": "Cadence", "desc": "+1 % de vitesse de tir"},
	"economie": {"name": "Économie", "desc": "+5 or au départ de chaque vague"},
	"rempart": {"name": "Rempart", "desc": "+1 vie au départ de l'expédition"},
	"chance": {"name": "Chance", "desc": "Jokers et reliques plus rares. À 10 pts, légendaires : 5 % des jokers, 8 % des reliques"},
	"preparation": {"name": "Préparation", "desc": "5 pts : une relique commune au départ. 10 pts : un emplacement de joker en plus"},
	"forge": {"name": "Forge", "desc": "-3 % sur le coût des fusions de reliques"},
}


## Score nécessaire pour gagner le n-ième point (n commence à 1).
static func point_cost(n: int) -> int:
	return FIRST_POINT_COST + COST_STEP * maxi(0, n - CHEAP_POINTS)


## Score cumulé total nécessaire pour avoir n points.
static func score_for_points(n: int) -> int:
	var total := 0
	for k in range(1, n + 1):
		total += point_cost(k)
	return total


## Nombre de points gagnés avec un score cumulé (on s'arrête au plafond).
static func points_for_score(score: int) -> int:
	var n := 0
	var needed := point_cost(1)
	while score >= needed and n < CAP:
		score -= needed
		n += 1
		needed = point_cost(n + 1)
	return n


static func get_upgrade(id: String) -> Dictionary:
	return DATA[id]
