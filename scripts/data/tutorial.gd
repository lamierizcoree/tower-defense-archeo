class_name Tutorial
extends RefCounted
## Le tutoriel : un petit niveau guidé, lancé depuis le camp de base.
## On y apprend à poser des murs, à lire le chemin des ennemis, à jouer des cartes
## (murs et tours), à lancer une vague, puis comment construire son deck.
##
## Chaque étape a un titre, un texte et une condition pour passer à la suivante :
##   "next"   : le joueur clique sur Suivant
##   sinon    : une condition vérifiée sur le niveau (voir done())
## L'expédition en cours, s'il y en a une, est mise de côté pendant le tutoriel (voir run_state.gd).

const LAYOUT := "d1"
const START_GOLD := 80
const WAVES := [
	{"enemies": ["eclaireur", "eclaireur", "eclaireur", "eclaireur", "eclaireur", "eclaireur"], "hp_mult": 0.8},
	{"enemies": ["eclaireur", "eclaireur", "rapide", "eclaireur", "rapide", "eclaireur", "rapide", "eclaireur"], "hp_mult": 0.9},
]
## Main de départ, puis les cartes piochées après la 1re vague (dans l'ordre).
const HAND := ["murs", "arbalete", "givre", "murs", "lampe"]
const NEXT_DRAWS := ["pointes", "arbalete", "murs"]
## Le reste du deck (pour qu'il fasse 20 cartes, comme un vrai deck).
const REST := ["murs", "murs", "arbalete", "baliste", "givre", "mortier", "alambic", "totem", "carabine", "pointes", "lampe", "murs"]

const STEPS := [
	{"title": "Bienvenue au chantier de fouilles !",
		"text": "Les ennemis sortent des cases vertes et marchent vers la case violette. Chacun qui l'atteint te coûte des vies.\nLes petits points rouges montrent leur chemin.",
		"until": "next"},
	{"title": "1. Pose des murs",
		"text": "Tu as 5 murs (en bas à gauche). Clique sur des cases vides, près des points, pour poser au moins 3 murs.\nObserve les points : le chemin fait un détour.",
		"until": "walls"},
	{"title": "2. Le chemin des ennemis",
		"text": "Les ennemis prennent toujours le chemin le plus court. Plus le détour est long, plus ils restent sous le feu de tes tours.\nUn mur qui fermerait tout le passage est refusé : il reste toujours un chemin.\nClic droit sur un mur : il revient dans ta réserve.",
		"until": "next"},
	{"title": "3. Plus de murs avec une carte",
		"text": "Tes actions viennent de ta main de cartes, en bas. Chaque carte coûte de l'or.\nClique sur la carte Pierres taillées : +3 murs pour 3 or. Pose-les ensuite.",
		"until": "wall_card"},
	{"title": "4. Pose une tour",
		"text": "Clique sur la carte Arbalète (elle s'encadre en jaune), puis clique sur un de tes murs : la tour se pose dessus.\nChoisis un mur collé au chemin. Le cercle bleu montre la portée.",
		"until": "tower"},
	{"title": "5. Une deuxième tour",
		"text": "Pose aussi le Givre : il ralentit tous les ennemis à sa portée, donc les autres tours tirent plus longtemps.\nSurvole une tour ou une carte pour voir ses chiffres.",
		"until": "two_towers"},
	{"title": "6. Lance la vague",
		"text": "Clique sur Vague ▶ en haut à droite (ou Espace).\nAvant, tu peux survoler « Prochaine vague (i) » pour voir qui arrive.",
		"until": "wave"},
	{"title": "Regarde-les marcher",
		"text": "Les ennemis suivent les points. Si tu poses un mur pendant la vague, ils changent de chemin aussitôt.\nVitesse x2 accélère le jeu.",
		"until": "wave_over"},
	{"title": "7. De nouvelles cartes",
		"text": "Après chaque vague, tu pioches 3 cartes. Les cartes jouées vont dans la défausse ; quand la pioche est vide, la défausse est remélangée.\nTu as pioché une Fosse à pieux : choisis-la, puis clique sur une case du chemin.",
		"until": "trap"},
	{"title": "8. Améliorer une tour",
		"text": "Clique sur une tour posée pour ouvrir son menu : le niveau 2 la renforce, le niveau 3 donne une spécialisation. Ça se paie en or.\nQuand tu es prêt, lance la dernière vague.",
		"until": "level_over"},
	{"title": "Bravo, le chantier est sauvé !",
		"text": "Dernière chose : ton deck. Au camp de base, le bouton « Deck de cartes » permet de choisir tes 20 cartes :\n• au moins une carte de tour et une carte de murs, 6 exemplaires au plus par carte ;\n• de nouvelles cartes se débloquent avec ton rang d'archéologue ;\n• après chaque victoire, l'atelier améliore une carte (2 fois au plus) pour toute l'expédition.\nUn bon deck a assez de murs pour construire et des tours variées.",
		"until": "end"},
]


## Liste des cartes du tutoriel, dans l'ordre : main, puis pioche (la fin de la liste est piochée d'abord).
static func deck() -> Array:
	var list := []
	for id in HAND + REST:
		list.append({"id": id, "lvl": 0})
	var next := NEXT_DRAWS.duplicate()
	next.reverse()
	for id in next:
		list.append({"id": id, "lvl": 0})
	return list


static func waves() -> Array:
	return WAVES.duplicate(true)


## L'étape est-elle terminée ? lv = le niveau (level.gd), start = ce qui a été noté au début de l'étape.
static func done(step: int, lv: Node, start: Dictionary) -> bool:
	match STEPS[step]["until"]:
		"walls":
			return lv.walls.size() >= 3
		"wall_card":
			return lv.cards_played.get("walls", 0) > int(start.get("walls_played", 0))
		"tower":
			return lv.towers.size() >= 1
		"two_towers":
			return lv.towers.size() >= 2
		"wave":
			return lv.wave_running or lv.wave_index >= 0
		"wave_over":
			return not lv.wave_running and lv.wave_index >= 0
		"trap":
			return lv.traps.size() >= 1 or lv.wave_running
		"level_over":
			return lv.ended
	return false
