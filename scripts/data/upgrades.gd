class_name Upgrades
extends RefCounted
## Les améliorations permanentes (méta-progression), comme dans le document de concept.
## Le score de chaque expédition s'ajoute au score cumulé : 1 point pour 1 000 points de score.
## On répartit ses points librement entre les catégories, et on peut les redistribuer à tout moment
## au camp de base. Au plus 50 points peuvent être utilisés, alors que les catégories en
## accepteraient 60 : il faut faire des choix.

const SCORE_PER_POINT := 1000
const CAP := 50
const MAX_PER_CATEGORY := 10

const ORDER := ["puissance", "cadence", "economie", "rempart", "chance", "preparation", "forge"]

const DATA := {
	"puissance": {"name": "Puissance", "desc": "+1 % de dégâts pour toutes les tours"},
	"cadence": {"name": "Cadence", "desc": "+1 % de vitesse de tir"},
	"economie": {"name": "Économie", "desc": "+5 or au départ de chaque vague"},
	"rempart": {"name": "Rempart", "desc": "+1 vie au départ de l'expédition"},
	"chance": {"name": "Chance", "desc": "+1 % de chances de joker rare et de relique plus rare"},
	"preparation": {"name": "Préparation", "desc": "5 pts : une relique commune au départ. 10 pts : un emplacement de joker en plus"},
	"forge": {"name": "Forge", "desc": "-3 % sur le coût des fusions (arrive avec la fusion des reliques)", "disabled": true},
}


static func get_upgrade(id: String) -> Dictionary:
	return DATA[id]
