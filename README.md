# Prototype Tower Defense (Godot 4)

Premier prototype du tower defense roguelite en labyrinthe : une grille où l'on pose des murs, des ennemis qui recalculent leur chemin à chaque mur posé, et les 6 tours de départ. Tout est dessiné avec des formes simples.

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
| R | Recommencer |

Les ennemis partent de la case verte et vont vers la case violette. Les petits points montrent leur chemin actuel. Un mur qui fermerait complètement le passage est refusé.

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

- `main.tscn` : la scène lancée au démarrage.
- `scripts/grid.gd` : taille de la grille, entrée, sortie, conversions case ↔ pixels.
- `scripts/main.gd` : murs, pathfinding (`AStarGrid2D`), vagues, or, vies, affichage.
- `scripts/enemy.gd` : un ennemi qui suit son chemin et le recalcule quand la grille change.
- `scripts/tower.gd` : le comportement des tours (tir, zone, ralentissement, poison, soutien).
- `scripts/tower_types.gd` : les chiffres des 6 tours (prix, portée, dégâts, cadence).

Les valeurs à modifier pour tester l'équilibrage (coûts, portée, dégâts, vitesse) sont des constantes en haut de chaque script.
