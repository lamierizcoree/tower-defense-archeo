class_name Events
extends RefCounted
## Les événements de la carte : une petite histoire et 2 ou 3 choix.
## Effets possibles d'un choix :
##   lives (vies gagnées ou perdues), treasure (trésor gagné ou dépensé),
##   relic (rareté minimale d'une relique gagnée), joker (rareté d'un joker gagné),
##   chance + success + fail : effet tiré au hasard (chance = probabilité de réussite).
## « desc » explique au joueur ce qui peut arriver, « text » raconte le résultat.

const DATA := {
	"sarcophage": {
		"name": "Le sarcophage scellé",
		"text": "Au fond d'une chambre funéraire, un sarcophage couvert de mises en garde. Quelque chose gratte à l'intérieur.",
		"choices": [
			{"label": "L'ouvrir", "desc": "50 % : une relique rare. Sinon : -4 vies.",
				"chance": 0.5, "success": {"relic": "rare", "text": "Un trésor oublié, et rien d'autre !"},
				"fail": {"lives": -4, "text": "Ce qui grattait était bien réveillé..."}},
			{"label": "Le laisser tranquille", "desc": "Rien ne se passe.", "text": "Sage décision. Probablement."},
		],
	},
	"inscription": {
		"name": "L'inscription murale",
		"text": "Une fresque couverte de symboles inconnus. Les déchiffrer pourrait révéler un secret... ou une malédiction.",
		"choices": [
			{"label": "La déchiffrer", "desc": "-3 vies, un joker peu commun.", "lives": -3, "joker": "non_commun",
				"text": "Tes yeux brûlent, mais le secret est à toi."},
			{"label": "La recopier pour le musée", "desc": "+30 trésor.", "treasure": 30, "text": "Le musée paiera bien."},
		],
	},
	"puits": {
		"name": "Le puits des souhaits",
		"text": "Un puits très ancien. On dit qu'il exauce les vœux des voyageurs généreux.",
		"choices": [
			{"label": "Jeter une pièce", "desc": "-10 trésor, +5 vies.", "treasure": -10, "lives": 5,
				"text": "Une douce chaleur t'envahit."},
			{"label": "Descendre au fond", "desc": "-2 vies, une relique.", "lives": -2, "relic": "commun",
				"text": "Une chute douloureuse, mais quelque chose brillait au fond."},
			{"label": "Passer son chemin", "desc": "Rien ne se passe.", "text": "Le puits reste silencieux."},
		],
	},
	"idole": {
		"name": "L'idole dorée",
		"text": "Une idole en or massif repose sur un piédestal. Le sol autour a l'air... piégé.",
		"choices": [
			{"label": "La prendre et courir", "desc": "+60 trésor, -3 vies.", "treasure": 60, "lives": -3,
				"text": "Le plafond s'effondre derrière toi. Tu t'en sors de justesse."},
			{"label": "L'échanger contre un sac de sable", "desc": "60 % : +60 trésor. Sinon : -5 vies.",
				"chance": 0.6, "success": {"treasure": 60, "text": "Le piège ne s'est pas déclenché !"},
				"fail": {"lives": -5, "text": "Le sac était trop léger. Le piège se déclenche."}},
			{"label": "La laisser", "desc": "Rien ne se passe.", "text": "Certaines choses doivent rester où elles sont."},
		],
	},
	"caravane": {
		"name": "Le marchand blessé",
		"text": "Un marchand ambulant gît près de sa charrette renversée. Il te supplie de l'aider.",
		"choices": [
			{"label": "Le soigner", "desc": "-2 vies, +45 trésor.", "lives": -2, "treasure": 45,
				"text": "Il te récompense généreusement avant de repartir."},
			{"label": "Ramasser ses caisses", "desc": "+15 trésor.", "treasure": 15, "text": "Il te remercie d'une petite bourse."},
		],
	},
	"carte": {
		"name": "La carte au trésor",
		"text": "Dans la poche d'un explorateur disparu, une carte marquée d'une croix rouge.",
		"choices": [
			{"label": "Suivre la carte", "desc": "70 % : +50 trésor. Sinon : -3 vies.",
				"chance": 0.7, "success": {"treasure": 50, "text": "La croix ne mentait pas !"},
				"fail": {"lives": -3, "text": "La croix marquait un nid de scorpions."}},
			{"label": "La vendre", "desc": "+20 trésor.", "treasure": 20, "text": "Un collectionneur te l'achète sans poser de questions."},
		],
	},
}


static func get_event(id: String) -> Dictionary:
	return DATA[id]


static func random_id(rng: RandomNumberGenerator) -> String:
	var ids := DATA.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]
