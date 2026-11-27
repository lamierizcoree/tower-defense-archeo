class_name Difficulty
extends RefCounted
## Les niveaux de difficulté, débloqués en réussissant des expéditions.
## Réussir une expédition au niveau le plus haut débloqué ouvre le suivant.
## Chaque niveau s'ajoute aux précédents : au niveau 3, les ennemis ont +60 % de PV.
## En échange, le score (donc les points d'amélioration) est plus élevé.

const MAX := 10
const HP_PER_LEVEL := 0.2       # +20 % de PV des ennemis par niveau
const SCORE_PER_LEVEL := 0.15   # +15 % de score par niveau


## Multiplicateur de PV des ennemis (boss et larves compris).
static func hp_mult(level: int) -> float:
	return 1.0 + HP_PER_LEVEL * level


## Multiplicateur de score à la fin de l'expédition.
static func score_mult(level: int) -> float:
	return 1.0 + SCORE_PER_LEVEL * level


static func name_of(level: int) -> String:
	return "Normale" if level == 0 else "Difficulté %d" % level


static func describe(level: int) -> String:
	if level == 0:
		return "La difficulté de base."
	return "Ennemis +%d %% de PV  ·  score +%d %%" % [roundi(HP_PER_LEVEL * level * 100), roundi(SCORE_PER_LEVEL * level * 100)]
