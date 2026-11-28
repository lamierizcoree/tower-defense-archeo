class_name Missions
extends RefCounted
## Les missions de fouille : un combat avec une contrainte.
## Réussir la mission garantit une relique rare (ou mieux) dans la récompense.

const DATA := {
	"aucune_fuite": {"name": "Fouille délicate", "desc": "Aucun ennemi ne doit s'échapper."},
	"peu_de_tours": {"name": "Équipe réduite", "desc": "4 tours au maximum.", "max_towers": 4},
	"peu_de_murs": {"name": "Sol fragile", "desc": "15 murs au maximum.", "max_walls": 15},
}


static func get_mission(id: String) -> Dictionary:
	return DATA[id]


static func random_id(rng: RandomNumberGenerator) -> String:
	var ids := DATA.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]
