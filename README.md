# Prototype Tower Defense (Godot 4)

Premier prototype du tower defense roguelite en labyrinthe : une grille où l'on pose des murs, des ennemis qui recalculent leur chemin à chaque mur posé, et une seule tour. Tout est dessiné avec des formes simples.

## Ouvrir et lancer le projet

1. Installe **Godot 4.3 ou plus récent** (version standard, pas « .NET ») depuis https://godotengine.org/download. C'est un seul fichier à lancer, sans installation.
2. Télécharge ce dépôt : bouton vert **Code** sur GitHub, puis **Download ZIP**, et décompresse-le. (Ou `git clone` si tu utilises Git.)
3. Lance Godot. Dans le gestionnaire de projets, clique sur **Importer**, choisis le fichier `project.godot` du dossier, puis **Importer et modifier**.
4. Dans l'éditeur, appuie sur **F5** (ou le bouton ▶ en haut à droite) pour jouer.

## Contrôles

| Touche | Action |
|---|---|
| Clic gauche | Poser un mur (mode 1) ou une tour sur un mur (mode 2) |
| Clic droit | Retirer une tour, sinon un mur (remboursé) |
| 1 / 2 | Mode Mur / mode Tour |
| Espace | Lancer la vague suivante |
| R | Recommencer |

Les ennemis partent de la case verte et vont vers la case violette. Les petits points montrent leur chemin actuel. Un mur qui fermerait complètement le passage est refusé.

## Organisation du code

- `main.tscn` : la scène lancée au démarrage.
- `scripts/grid.gd` : taille de la grille, entrée, sortie, conversions case ↔ pixels.
- `scripts/main.gd` : murs, pathfinding (`AStarGrid2D`), vagues, or, vies, affichage.
- `scripts/enemy.gd` : un ennemi qui suit son chemin et le recalcule quand la grille change.
- `scripts/tower.gd` : la tour à cible unique (future « Arbalète »).

Les valeurs à modifier pour tester l'équilibrage (coûts, portée, dégâts, vitesse) sont des constantes en haut de chaque script.
