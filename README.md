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

Les ennemis partent des cases vertes et vont vers la case violette. Les petits points montrent leur chemin actuel. Un mur qui fermerait complètement le passage est refusé. On peut aussi cliquer sur la barre du bas pour choisir quoi construire.

Pour voir les détails, passe la souris :
- sur une tour (posée ou dans la barre du bas) : dégâts, tirs par seconde, portée, effet spécial, prix ;
- sur la ligne « Prochaine vague » (ⓘ) : nombre d'ennemis de chaque type, points de vie, vitesse, vies perdues s'ils s'échappent et capacités spéciales ;
- sur un ennemi : ses points de vie restants et ses effets en cours.

## L'expédition

1. **La carte** : on choisit son prochain niveau parmi ceux entourés. ⚔ = combat (2 vagues), ! = élite (3 vagues plus dures, une récompense rare garantie), ☠ = boss (3 vagues, le boss arrive à la dernière).
2. **Le niveau** : on repart d'une grille vide avec de l'or neuf. Les vies, elles, se gardent d'un niveau à l'autre.
3. **La récompense** : 1 joker parmi 3, ou passer pour gagner 3 vies. On garde 5 jokers au maximum : au-delà, il faut en abandonner un.
4. Après le boss du désert, on passe à la glace. Après le boss de la glace, l'expédition est réussie.

### Les biomes

| Biome | Règles |
|---|---|
| Désert | Des dunes recouvrent 4 cases entre les vagues. Une vague sur deux, une tempête réduit la portée de 25 %. Ennemis plus rapides. Les fouisseurs creusent sous les murs. Boss : le Scarabée-Roi. |
| Glace | Les ennemis vont deux fois plus vite sur les cases gelées. Les tours tirent 15 % moins vite. Plus de colosses. Boss : le Colosse gelé. |

Chaque biome a 5 niveaux et une salle de boss, dessinés à la main dans `scripts/data/levels.gd`.

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

- `scenes/` : les 4 écrans (carte, niveau, récompense, fin). La carte est lancée au démarrage.
- `scripts/run_state.gd` : l'expédition en cours (vies, jokers, score, carte), accessible partout sous le nom `Run`.
- `scripts/map_gen.gd` : création de la carte à embranchements.
- `scripts/level.gd` : un niveau (murs, pathfinding `AStarGrid2D`, vagues, dunes, tempête, affichage).
- `scripts/map_screen.gd`, `scripts/reward_screen.gd`, `scripts/end_screen.gd` : les autres écrans.
- `scripts/data/` : les données à modifier pour équilibrer (biomes, plans des niveaux, ennemis, jokers).
- `scripts/grid.gd` : taille de la grille, conversions case ↔ pixels.
- `scripts/enemy.gd` : un ennemi qui suit son chemin et le recalcule quand la grille change.
- `scripts/tower.gd` : le comportement des tours (tir, zone, ralentissement, poison, soutien).
- `scripts/tower_types.gd` : les chiffres des 6 tours (prix, portée, dégâts, cadence).

Les valeurs à modifier pour tester l'équilibrage (coûts, portée, dégâts, vitesse) sont des constantes en haut de chaque script.
