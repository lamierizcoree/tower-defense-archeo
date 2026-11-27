class_name EnemyTypes
extends RefCounted
## Les types d'ennemis. hp et speed sont les valeurs de base, avant la difficulté du niveau.
## damage = vies perdues si l'ennemi atteint la sortie. score = points gagnés en le tuant.
## ability = capacité spéciale, affichée dans le détail des vagues.

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
	"scarabee": {
		"name": "Scarabée-Roi", "plural": "Scarabée-Roi", "shape": "boss",
		"hp": 900.0, "speed": 34.0, "radius": 24.0, "color": Color("2f7d68"),
		"damage": 10, "score": 300, "boss": true,
		"ability": "Boss. Résiste à moitié aux ralentissements. Coûte 10 vies.",
	},
	"colosse_gele": {
		"name": "Colosse gelé", "plural": "Colosse gelé", "shape": "boss",
		"hp": 1100.0, "speed": 30.0, "radius": 26.0, "color": Color("4f86b5"),
		"damage": 10, "score": 400, "boss": true,
		"ability": "Boss. Résiste à moitié aux ralentissements. Coûte 10 vies.",
	},
}


static func get_type(id: String) -> Dictionary:
	return DATA[id]
