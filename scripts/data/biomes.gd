class_name Biomes
extends RefCounted
## Les biomes de l'expédition, dans l'ordre où on les traverse.
## Chaque biome change le terrain, les ennemis et le rythme des tours.

const LIST := [
	{
		"id": "desert",
		"name": "Désert",
		"subtitle": "Les ruines ensablées",
		"boss": "scarabee",
		"rules": [
			"Des dunes recouvrent des cases entre les vagues.",
			"Une vague sur deux, une tempête de sable réduit la portée de 25 %.",
			"Ennemis rapides, et les fouisseurs creusent sous les murs.",
		],
		"enemy_speed": 1.15,
		"tower_cadence": 1.0,
		"fast_share": 0.35,
		"diggers": true,
		"colors": {
			"background": Color("2b2420"),
			"tile_a": Color("e0c38c"),
			"tile_b": Color("d8b981"),
			"rock": Color("b59a72"),
			"rock_edge": Color("6e5a40"),
		},
	},
	{
		"id": "glace",
		"name": "Glace",
		"subtitle": "Le glacier des oubliés",
		"boss": "colosse_gele",
		"rules": [
			"Les ennemis glissent sur la glace : vitesse doublée sur les cases gelées.",
			"Le froid engourdit les tours : cadence de tir -15 %.",
			"Plus de colosses, moins de rapides.",
		],
		"enemy_speed": 1.0,
		"tower_cadence": 0.85,
		"fast_share": 0.15,
		"diggers": false,
		"colors": {
			"background": Color("1c2430"),
			"tile_a": Color("e6eef5"),
			"tile_b": Color("dce6ef"),
			"rock": Color("7c8a99"),
			"rock_edge": Color("4b5866"),
		},
	},
]


static func count() -> int:
	return LIST.size()


static func get_biome(index: int) -> Dictionary:
	return LIST[index]
