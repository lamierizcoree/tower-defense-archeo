class_name EnemyTypes
extends RefCounted
## Les types d'ennemis. hp et speed sont les valeurs de base, avant la difficulté du niveau.
## damage = vies perdues si l'ennemi atteint la sortie. score = points gagnés en le tuant.
## ability = capacité spéciale, affichée dans le détail des vagues.
## gold = or gagné en le tuant (3 si absent).
## splits / split_count = type et nombre d'ennemis libérés à sa mort.

const DATA := {
	"eclaireur": {
		"name": "éclaireur", "plural": "éclaireurs", "shape": "circle",
		"hp": 30.0, "speed": 70.0, "radius": 13.0, "color": Color("c94a3d"),
		"damage": 1, "score": 5,
		"ability": "Aucune capacité spéciale.",
	},
	"rapide": {
		"name": "rapide", "plural": "rapides", "shape": "triangle",
		"hp": 18.0, "speed": 115.0, "radius": 11.0, "color": Color("e07b39"),
		"damage": 1, "score": 5,
		"ability": "Très rapide mais fragile.",
	},
	"colosse": {
		"name": "colosse", "plural": "colosses", "shape": "square",
		"hp": 110.0, "speed": 45.0, "radius": 17.0, "color": Color("7a3b2e"),
		"damage": 2, "score": 15,
		"ability": "Très résistant. Coûte 2 vies s'il s'échappe.",
	},
	"fouisseur": {
		"name": "fouisseur", "plural": "fouisseurs", "shape": "digger",
		"hp": 35.0, "speed": 60.0, "radius": 13.0, "color": Color("9c6b3a"),
		"damage": 1, "score": 10, "digs": true,
		"ability": "Creuse sous les murs et prend toujours le chemin le plus court, sauf sous les murs scellés.",
	},
	"jarre": {
		"name": "jarre", "plural": "jarres", "shape": "jar",
		"hp": 70.0, "speed": 55.0, "radius": 15.0, "color": Color("b5653a"),
		"damage": 1, "score": 12, "splits": "larve", "split_count": 3,
		"ability": "Assez résistante. En se brisant, libère 3 larves très rapides.",
	},
	"larve": {
		"name": "larve", "plural": "larves", "shape": "larva",
		"hp": 8.0, "speed": 150.0, "radius": 8.0, "color": Color("e8d36a"),
		"damage": 1, "score": 2, "gold": 1,
		"ability": "Sort d'une jarre brisée. Très rapide mais très fragile.",
	},
	"scarabee": {
		"name": "Scarabée-Roi", "plural": "Scarabée-Roi", "shape": "boss",
		"hp": 900.0, "speed": 34.0, "radius": 24.0, "color": Color("2f7d68"),
		"damage": 5, "score": 300, "boss": true,
		"ability": "Boss. Résiste à moitié aux ralentissements. Coûte 5 vies s'il s'échappe, et la récompense ne dépasse pas une relique rare.",
	},
	"colosse_gele": {
		"name": "Colosse gelé", "plural": "Colosse gelé", "shape": "boss",
		"hp": 1100.0, "speed": 30.0, "radius": 26.0, "color": Color("4f86b5"),
		"damage": 5, "score": 400, "boss": true,
		"ability": "Boss. Résiste à moitié aux ralentissements. Coûte 5 vies s'il s'échappe, et la récompense ne dépasse pas une relique rare.",
	},
}


static func get_type(id: String) -> Dictionary:
	return DATA[id]
