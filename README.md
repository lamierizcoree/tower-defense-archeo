# Prototype Tower Defense (Godot 4)

Prototype du tower defense roguelite en labyrinthe. Une expédition traverse 2 biomes (désert puis glace). Chaque biome est une carte à embranchements de 5 étages qui se termine par un boss. Après chaque niveau, on choisit un joker parmi 3. Tout est dessiné avec des formes simples.

## Ouvrir et lancer le projet

1. Installe **Godot 4.3 ou plus récent** (version standard, pas « .NET ») depuis https://godotengine.org/download. C'est un seul fichier à lancer, sans installation.
2. Télécharge ce dépôt : bouton vert **Code** sur GitHub, puis **Download ZIP**, et décompresse-le. (Ou `git clone` si tu utilises Git.)
3. Lance Godot. Dans le gestionnaire de projets, clique sur **Importer**, choisis le fichier `project.godot` du dossier, puis **Importer et modifier**.
4. Dans l'éditeur, appuie sur **F5** (ou le bouton ▶ en haut à droite) pour jouer.

## Contrôles

| Touche | Action |
|---|---|
| Clic gauche | Poser un mur, ou la tour choisie sur un mur |
| Clic droit | Retirer une tour (moitié du prix rendue), sinon un mur (remboursé) |
| 1 | Construire des murs |
| 2 à 7 | Choisir une tour |
| Espace | Lancer la vague suivante |
| F | Vitesse x2 |
| E | Tourner une tour qui porte la Lance du Pharaon (souris sur la tour) |

Les ennemis partent des cases vertes et vont vers la case violette. Les petits points montrent leur chemin actuel. Un mur qui fermerait complètement le passage est refusé. On peut aussi cliquer sur la barre du bas pour choisir quoi construire.

Pour voir les détails, passe la souris :
- sur une tour (posée ou dans la barre du bas) : dégâts, tirs par seconde, portée, effet spécial, prix ;
- sur la ligne « Prochaine vague » (ⓘ) : nombre d'ennemis de chaque type, points de vie, vitesse, vies perdues s'ils s'échappent et capacités spéciales ;
- sur un ennemi : ses points de vie restants et ses effets en cours.

## Le camp de base

Le jeu démarre au camp de base :
- **Nouvelle expédition** (ou **Continuer** si une expédition est en cours).
- **Carnet des reliques et pouvoirs** : la liste de toutes les reliques et de tous les jokers. Les reliques pas encore débloquées sont masquées, avec le rang qui les débloque. Le carnet s'ouvre aussi depuis la carte (bouton en haut à droite).
- **Améliorations** : on répartit ses points d'amélioration.

### Progression

- **Rang d'archéologue** : +1 à chaque niveau réussi, toutes expéditions confondues. Chaque rang débloque de nouvelles reliques, qui peuvent alors apparaître dans les récompenses.

| Rang | Reliques débloquées |
|---|---|
| 0 | Pointe de silex, Plume de vautour, Lentille fêlée, Amulette de bronze, Rouage ancien, Scarabée d'or |
| 2 | Longue-vue de cuivre |
| 4 | Ambre fossile |
| 5 | Sceau de granit, Lance du Pharaon |
| 6 | Sablier de quartz |
| 8 | Œil de faucon |
| 10 | Couronne du Scarabée-Roi |
| 12 | Cristal des glaces |
| 15 | Cœur du Colosse gelé |

- **Points d'amélioration** : le score de chaque expédition s'ajoute au score cumulé, qui donne des points. Chaque point coûte plus cher que le précédent : les 4 premiers coûtent 1 000 de score (environ une expédition réussie), puis chaque point coûte 250 de plus que le précédent. On peut utiliser au plus 50 points, et les redistribuer librement entre deux expéditions.

| Points | Score cumulé nécessaire | Environ (expéditions réussies) |
|---|---|---|
| 4 | 4 000 | 1 |
| 10 | 15 250 | 3 à 4 |
| 20 | 54 000 | 12 |
| 30 | 117 750 | 27 |
| 50 | 320 250 | 70 |

Pour régler ce rythme : `FIRST_POINT_COST`, `CHEAP_POINTS` et `COST_STEP` dans `scripts/data/upgrades.gd`.

| Catégorie | Effet par point (10 points au maximum) |
|---|---|
| Puissance | +1 % de dégâts |
| Cadence | +1 % de vitesse de tir |
| Économie | +5 or au départ de chaque vague |
| Rempart | +1 vie au départ de l'expédition |
| Chance | +1 % de joker rare et de relique plus rare |
| Préparation | 5 pts : une relique commune au départ ; 10 pts : un emplacement de joker en plus |
| Forge | Arrivera avec la fusion des reliques |

Le profil est sauvegardé automatiquement (fichier `profil.json` dans le dossier de données de Godot). Le bouton « Effacer le profil » du camp de base le remet à zéro.

## L'expédition

1. **La carte** : on choisit son prochain niveau parmi ceux entourés. ⚔ = combat (2 vagues), ! = élite (3 vagues plus dures, une récompense rare garantie), ☠ = boss (3 vagues, le boss arrive à la dernière).
2. **Le niveau** : on repart d'une grille vide avec de l'or neuf. Les vies, elles, se gardent d'un niveau à l'autre.
3. **La récompense** : 1 carte parmi 3 (joker ou relique), ou passer pour gagner 3 vies. On garde 5 jokers et 8 reliques au maximum : au-delà, il faut en abandonner un.
4. Après le boss du désert, on passe à la glace. Après le boss de la glace, l'expédition est réussie.

### Les biomes

| Biome | Règles |
|---|---|
| Désert | Des dunes recouvrent 4 cases entre les vagues. Une vague sur deux, une tempête réduit la portée de 25 %. Ennemis plus rapides. Les fouisseurs creusent sous les murs. Boss : le Scarabée-Roi. |
| Glace | Les ennemis vont deux fois plus vite sur les cases gelées. Les tours tirent 15 % moins vite. Plus de colosses. Boss : le Colosse gelé. |

Chaque biome a 5 niveaux et une salle de boss, dessinés à la main dans `scripts/data/levels.gd`.

### Les reliques

Les reliques sont des artefacts déterrés qu'on place dans les emplacements des tours. On les trouve dans les récompenses : parfois après un combat, toujours une rare ou légendaire après une élite, et une légendaire après un boss tué (même si aucune n'est encore débloquée : on reçoit alors la plus facile à débloquer). Si le boss s'échappe, il coûte 5 vies et la récompense ne dépasse pas une relique rare. On en garde 8 au maximum.

Pendant un niveau, la barre du bas montre tes reliques. Clique sur une relique, puis sur une tour, pour l'y poser. Clique sur une relique déjà posée pour la retirer. Une tour vendue rend ses reliques, et toutes les reliques reviennent dans l'inventaire au niveau suivant.

Chaque tour porte **une seule relique**. Le joker rare **Écrin double** permet d'en porter 2. Dans tous les cas, une tour ne peut avoir qu'une seule légendaire, et le Totem n'en accepte aucune.

| Rareté | Reliques | Effet |
|---|---|---|
| Commune | Pointe de silex, Plume de vautour, Lentille fêlée | +15 % dégâts, cadence ou portée |
| Peu commune | Amulette de bronze, Rouage ancien, Longue-vue de cuivre, Ambre fossile | +25 % dégâts, cadence ou portée, ou +30 % effets spéciaux |
| Rare | Scarabée d'or, Sablier de quartz, Œil de faucon, Cristal des glaces | +40 % sur une stat et +15 % sur une autre |
| Rare | Sceau de granit | Les murs à portée de la tour ne peuvent plus être creusés par les fouisseurs (losange bleu sur le mur), +15 % portée |
| Légendaire | Lance du Pharaon | Dégâts x4, mais la tour tire en ligne droite dans une direction (E pour tourner), sur autant de cases que sa portée de base |
| Légendaire | Couronne du Scarabée-Roi | Dégâts x3 et cadence x1,5, mais portée de 1,5 case |
| Légendaire | Cœur du Colosse gelé | Cadence x3, mais ne vise que les ennemis ralentis |

Une seule légendaire par tour. Les « effets spéciaux » sont la durée du ralentissement, la force du poison, le rayon d'explosion et le bonus du Totem.

### Les jokers

| Joker | Effet |
|---|---|
| Maçon | Chaque mur ou rocher collé à une tour lui donne +12 de portée |
| Cul-de-sac | Une tour bloquée sur 3 côtés ou plus inflige double dégâts |
| Pillard | Chaque ennemi qui s'échappe rapporte 6 or |
| Briques creuses | Les murs coûtent 1 or |
| Prime de chasse | +2 or par ennemi tué |
| Long détour | Au début de chaque vague, +1 or toutes les 3 cases du chemin |
| Givre éternel | Ralentissements plus longs et plus forts |
| Venin glacé | Le poison fait double dégâts aux ennemis ralentis |
| Artilleur | Explosions du Mortier 50 % plus larges |
| Totems ancestraux | Les bonus de plusieurs Totems se cumulent |
| Fondations | Tours 25 % moins chères |
| Rempart | +2 vies au début de chaque niveau |
| Écho (rare) | Les tirs d'Arbalète et de Baliste rebondissent sur un 2e ennemi |
| Fiole instable (rare) | Un ennemi empoisonné qui meurt explose |
| Sablier ancien (rare) | Première vague de chaque niveau : ennemis 30 % plus lents |
| Écrin double (rare) | Chaque tour peut porter 2 reliques (toujours une seule légendaire) |

## Les tours

| Touche | Tour | Prix | Rôle |
|---|---|---|---|
| 2 | Arbalète | 15 | Tir rapide sur un ennemi |
| 3 | Baliste | 30 | Gros dégâts, grande portée, lente |
| 4 | Mortier | 35 | Dégâts de zone, ne tire pas de près |
| 5 | Givre | 20 | Ralentit tous les ennemis à portée |
| 6 | Alambic | 25 | Empoisonne, vise d'abord les ennemis sains |
| 7 | Totem | 30 | N'attaque pas : les tours voisines tirent 30 % plus vite |

## Organisation du code

- `scenes/` : les écrans (camp de base, carnet, améliorations, carte, niveau, récompense, fin). Le camp de base est lancé au démarrage.
- `scripts/run_state.gd` : l'expédition en cours (vies, jokers, score, carte), accessible partout sous le nom `Run`.
- `scripts/profile.gd` : le profil sauvegardé (rang, score cumulé, points répartis), accessible partout sous le nom `Profile`.
- `scripts/map_gen.gd` : création de la carte à embranchements.
- `scripts/level.gd` : un niveau (murs, pathfinding `AStarGrid2D`, vagues, dunes, tempête, affichage).
- `scripts/map_screen.gd`, `scripts/reward_screen.gd`, `scripts/end_screen.gd` : les autres écrans.
- `scripts/data/` : les données à modifier pour équilibrer (biomes, plans des niveaux, ennemis, jokers, reliques, améliorations).
- `scripts/grid.gd` : taille de la grille, conversions case ↔ pixels.
- `scripts/enemy.gd` : un ennemi qui suit son chemin et le recalcule quand la grille change.
- `scripts/tower.gd` : le comportement des tours (tir, zone, ralentissement, poison, soutien).
- `scripts/tower_types.gd` : les chiffres des 6 tours (prix, portée, dégâts, cadence).

Les valeurs à modifier pour tester l'équilibrage (coûts, portée, dégâts, vitesse) sont des constantes en haut de chaque script.
