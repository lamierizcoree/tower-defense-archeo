# Prototype Tower Defense (Godot 4)

Prototype du tower defense roguelite en labyrinthe. Une expédition traverse 2 biomes (désert puis glace). Chaque biome est une carte à embranchements de 5 étages qui se termine par un boss. Après chaque niveau, on choisit un joker parmi 3. Tout est dessiné avec des formes simples.

## Ouvrir et lancer le projet

1. Installe **Godot 4.7** (version standard, pas « .NET ») depuis https://godotengine.org/download. C'est un seul fichier à lancer, sans installation.
2. Télécharge ce dépôt : bouton vert **Code** sur GitHub, puis **Download ZIP**, et décompresse-le. (Ou `git clone` si tu utilises Git.)
3. Lance Godot. Dans le gestionnaire de projets, clique sur **Importer**, choisis le fichier `project.godot` du dossier, puis **Importer et modifier**.
4. Dans l'éditeur, appuie sur **F5** (ou le bouton ▶ en haut à droite) pour jouer.

## Contrôles

| Touche | Action |
|---|---|
| Clic gauche | Poser un mur, ou jouer la carte choisie (tour sur un mur, piège sur une case libre) |
| Clic droit | Retirer une tour (moitié du prix rendue), sinon un mur (il revient dans la réserve) ; annule la carte choisie |
| 1 | Mode Mur (poser les murs de la réserve) |
| 2 à 9, 0 | Choisir ou jouer une carte de la main |
| Espace | Lancer la vague suivante |
| F | Vitesse x2 |
| E | Tourner une tour qui porte la Lance du Pharaon (souris sur la tour) |

Les ennemis partent des cases vertes et vont vers la case violette. Les petits points montrent leur chemin actuel. Un mur qui fermerait complètement le passage est refusé. On peut aussi cliquer sur les cartes de la barre du bas.

Pour voir les détails, passe la souris :
- sur une tour posée ou une carte de la main : dégâts, tirs par seconde, portée, effet spécial, prix ;
- sur la réserve de murs (en bas à gauche) : murs restants, pioche, défausse, effets en cours ;
- sur la ligne « Prochaine vague » (ⓘ) : nombre d'ennemis de chaque type, points de vie, vitesse, vies perdues s'ils s'échappent et capacités spéciales ;
- sur un ennemi : ses points de vie restants et ses effets en cours.

## Le camp de base

Le jeu démarre au camp de base :
- **Nouvelle expédition** (ou **Continuer** si une expédition est en cours).
- **Deck de cartes** : on choisit les 20 cartes de son deck (voir plus bas).
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
| Chance | Jokers et reliques plus rares. Chaque point rapproche les chances de leur maximum, atteint à 10 points : jokers 25 % commun, 50 % non commun, 20 % rare, 5 % légendaire ; reliques 22 / 50 / 20 / 8 % |
| Préparation | 5 pts : une relique commune au départ ; 10 pts : un emplacement de joker en plus |
| Forge | -3 % sur le prix des fusions de reliques par point (-30 % à 10 points) |

Le profil est sauvegardé automatiquement (fichier `profil.json` dans le dossier de données de Godot). Le bouton « Effacer le profil » du camp de base le remet à zéro.

### Niveaux de difficulté

Réussir une expédition débloque le niveau de difficulté suivant (jusqu'à 10). On le choisit au camp de base avec les flèches, avant de partir (survoler le nom affiche les règles). Pour débloquer le niveau suivant, il faut réussir au niveau le plus haut déjà débloqué.

Chaque niveau ajoute **une nouvelle règle**, qui s'ajoute à celles des niveaux précédents. En échange, le score augmente de 15 % par niveau.

| Niveau | Règle | Effet |
|---|---|---|
| 1 | Élites errants | 1 ennemi sur 10 est un élite (cercle doré) : PV x2,5, coûte 1 vie de plus, rapporte double or et triple score |
| 2 | Vents contraires | Ennemis +10 % de vitesse |
| 3 | Fouilles coûteuses | Les cartes de murs coûtent 2 or de plus |
| 4 | Rivalité des ateliers | À partir de 3 tours identiques, ces tours tirent 20 % moins vite |
| 5 | Bourse maigre | 25 % d'or en moins au début de chaque niveau |
| 6 | Carrière épuisée | 20 murs au maximum par niveau |
| 7 | Garde rapprochée | Le boss arrive avec 2 colosses élites |
| 8 | Butin pillé | Chaque ennemi tué rapporte 1 or de moins (au moins 1) |
| 9 | Chair maudite | Les ennemis regagnent 2 % de leurs PV par seconde, sauf s'ils sont empoisonnés |
| 10 | Expédition de trop | 8 vies de moins au départ |

Les règles et leurs chiffres sont dans `scripts/data/difficulty.gd`.

## L'expédition

1. **La carte** : on choisit sa prochaine étape parmi celles entourées. Le premier étage n'a que des combats, et l'étage juste avant le boss contient toujours un marchand ou un feu de camp.
   - ⚔ combat : 5 vagues.
   - ! élite : 5 vagues plus dures, une récompense rare garantie.
   - ✦ fouille : 5 vagues avec une mission (aucune fuite, 4 tours maximum, ou 15 murs maximum). Mission réussie = une relique rare au moins.
   - ? événement : une découverte avec un choix (sarcophage, inscription, puits, idole, caravane, carte). Certains choix sont risqués.
   - $ marchand : 3 reliques, 2 jokers et une trousse de soins (+3 vies), payés en trésor.
   - ▲ feu de camp : au choix, se reposer (+6 vies), fouiller les environs (+25 trésor) ou se défaire d'un joker.
   - ☠ boss : 5 vagues, le boss arrive à la dernière.
2. **Le niveau** : on repart d'une grille vide avec de l'or neuf, 5 murs et une nouvelle main de cartes (voir « Le deck de cartes »). Les vies, elles, se gardent d'un niveau à l'autre.
3. **La récompense** : 1 carte parmi 3 (joker ou relique), ou passer pour gagner 3 vies. On garde 5 jokers et 8 reliques au maximum : au-delà, il faut en abandonner un.
4. **L'atelier de cartes** : après chaque victoire, on améliore une carte du deck. On peut aussi graver une relique (elle est détruite) pour une amélioration de plus, et acheter une relique ou un joker à l'étal avec le trésor.
5. **Le bilan** : à la fin de chaque niveau réussi, un bilan montre les ennemis vaincus, les fuites, l'or gagné, le trésor gardé, le score, et les dégâts de chaque tour (la meilleure est marquée d'une étoile). Espace ou clic pour continuer.
6. **Le trésor** : à la fin de chaque niveau, la moitié de l'or restant devient du trésor, qui se garde pour toute l'expédition. On le dépense chez le marchand et dans certains événements. Une relique ou un joker gagné sans place libre est revendu automatiquement en trésor.
7. Après le boss du désert, on passe à la glace. Après le boss de la glace, l'expédition est réussie.

### Les biomes

| Biome | Règles |
|---|---|
| Désert | Des dunes recouvrent 4 cases entre les vagues. Une vague sur deux, une tempête réduit la portée de 25 %. Ennemis plus rapides. Les fouisseurs creusent sous les murs. Boss : le Scarabée-Roi. |
| Glace | Les ennemis vont deux fois plus vite sur les cases gelées. Les tours tirent 15 % moins vite. Plus de colosses. Boss : le Colosse gelé. |

Chaque biome a 5 niveaux et une salle de boss, dessinés à la main dans `scripts/data/levels.gd`.

### Les ennemis

| Ennemi | Arrive à partir de | Capacité |
|---|---|---|
| Éclaireur | début | Aucune |
| Rapide | début | Très rapide mais fragile |
| Colosse | niveau 3 | Très résistant, coûte 2 vies |
| Fouisseur | niveau 2 (désert) | Creuse sous les murs, prend le plus court chemin |
| Jarre | niveau 2 | Libère 3 larves très rapides en se brisant |
| Ibis | niveau 3 | Vole tout droit par-dessus les murs. Le Mortier ne peut pas le toucher |
| Embaumeur | niveau 4 | Soigne les ennemis proches de 6 % de leurs PV par seconde, sauf les empoisonnés |
| Pilleur | niveau 5 | Toutes les 5 s, bloque la tour la plus proche pendant 2,5 s |

Les deux boss ont **deux phases**. Sous la moitié de ses PV, le Scarabée-Roi accélère et appelle 4 rapides. Le Colosse gelé gèle les tours proches pendant 4 s et libère 2 colosses.

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

#### La fusion de reliques

Le bouton **Forge** de la carte permet de fusionner deux reliques de **même rareté** en une relique de la rareté au-dessus. Si les deux ont un bonus en commun (dégâts, cadence, portée, effets spéciaux), la nouvelle relique l'a aussi si possible. Deux rares donnent une légendaire. Les légendaires ne se fusionnent pas.

Prix en trésor : 15 pour deux communes, 30 pour deux peu communes, 60 pour deux rares (moins avec l'amélioration Forge). Au feu de camp, l'option « Forger » offre une fusion gratuite.

### Les jokers

Comme les reliques, les jokers ont 4 raretés. À chaque carte joker, les chances sont : commun 55 %, non commun 30 %, rare 12 %, légendaire 3 %. Après une élite, une carte est au moins rare ; après un boss, deux cartes. La stat Chance du camp de base rend les raretés plus fréquentes (voir plus haut). Les réglages sont en haut de `scripts/data/jokers.gd`.

| Rareté | Joker | Effet |
|---|---|---|
| Commun | Maçon | Chaque mur ou rocher collé à une tour lui donne +12 de portée |
| Commun | Pillard | Chaque ennemi qui s'échappe rapporte 6 or |
| Commun | Briques creuses | Chaque carte de murs donne 1 mur de plus |
| Commun | Prime de chasse | +2 or par ennemi tué |
| Commun | Fondations | Cartes de tour 25 % moins chères |
| Commun | Rempart | +2 vies au début de chaque niveau |
| Non commun | Butin de fouille | +30 % d'or gagné pendant les vagues |
| Non commun | Cul-de-sac | Une tour bloquée sur 3 côtés ou plus inflige double dégâts |
| Non commun | Long détour | Au début de chaque vague, +1 or toutes les 3 cases du chemin |
| Non commun | Givre éternel | Ralentissements plus longs et plus forts |
| Non commun | Venin glacé | Le poison fait double dégâts aux ennemis ralentis |
| Non commun | Artilleur | Explosions du Mortier 50 % plus larges |
| Non commun | Totems ancestraux | Les bonus de plusieurs Totems se cumulent |
| Rare | Écho | Les tirs d'Arbalète et de Baliste rebondissent sur un 2e ennemi |
| Rare | Fiole instable | Un ennemi empoisonné qui meurt explose |
| Rare | Sablier ancien | Première vague de chaque niveau : ennemis 30 % plus lents |
| Rare | Écrin double | Chaque tour peut porter 2 reliques (toujours une seule légendaire) |
| Légendaire | Esprit de meute | +10 % de cadence par autre tour du même type posée (+50 % au maximum) |
| Légendaire | Trésor maudit | Or gagné pendant les vagues x2, mais ennemis +25 % de PV |
| Légendaire | Architecte fou | 10 murs de plus au début de chaque niveau, mais cartes de tour 50 % plus chères |

### Les synergies de jokers

Chaque joker appartient à un **clan**. Avoir 2 puis 3 jokers d'un même clan donne un bonus en plus. Certaines paires forment un **duo** avec un effet à part. Les cartes de récompense indiquent ce qu'un joker activerait, et le carnet a un onglet « Synergies ».

| Clan | Jokers | 2 jokers | 3 jokers |
|---|---|---|---|
| ■ Bâtisseurs | Maçon, Briques creuses, Fondations, Cul-de-sac, Architecte fou | Tours +10 % de portée | +6 % de dégâts par mur ou rocher collé à la tour |
| $ Marchands | Pillard, Prime de chasse, Butin de fouille, Long détour, Trésor maudit | +15 or au début de chaque niveau | 75 % de l'or restant devient du trésor (au lieu de 50 %) |
| ⚗ Alchimistes | Venin glacé, Fiole instable, Givre éternel, Artilleur, Sablier ancien | Effets spéciaux +20 % | Ennemi ralenti et empoisonné : +25 % de dégâts subis |
| ♜ Stratèges | Écho, Totems ancestraux, Esprit de meute, Écrin double, Rempart | Tours +10 % de cadence | Niveau sans aucune fuite : +2 vies |

| Duo | Jokers | Effet |
|---|---|---|
| Forteresse | Maçon + Cul-de-sac | Tour bloquée sur 3 côtés : +25 % de portée |
| Cryotoxine | Venin glacé + Givre éternel | Le poison ralentit aussi de 15 % |
| Poudre noire | Fiole instable + Artilleur | Explosion de la Fiole 50 % plus large, dégâts x2 |
| Chasseur de primes | Prime de chasse + Butin de fouille | Élites et boss : +10 or |
| Cartographe | Long détour + Sablier ancien | Long détour : +1 or toutes les 2 cases au lieu de 3 |
| Arsenal | Écho + Esprit de meute | Les rebonds d'Écho font 100 % des dégâts |

## Le deck de cartes

On ne pose plus les tours avec un budget libre : on joue des **cartes**, piochées dans un deck de 20 cartes, et chaque carte coûte de l'or selon sa puissance.

- **Au début de chaque niveau** : tout le deck est mélangé, on pioche **5 cartes** (toujours au moins une carte de tour et une carte de murs) et on a **5 murs** à poser.
- **Après chaque vague** : on pioche **3 cartes** de plus. La main contient 9 cartes au maximum (une carte piochée en trop part dans la défausse).
- **Pioche vide** : la défausse est remélangée et forme une nouvelle pioche.
- **Jouer une carte** : les cartes de murs, de malus et de bonus se jouent d'un clic. Les cartes de tour et de piège se choisissent, puis on clique sur un mur (tour) ou sur une case libre (piège). La carte jouée part dans la défausse.
- Les murs ne coûtent plus d'or : on pose ceux de la réserve. Un mur retiré revient dans la réserve.

| Carte | Type | Prix | Effet | Amélioration 1 | Amélioration 2 | Rang |
|---|---|---|---|---|---|---|
| Pierres taillées | Construction | 3 | +3 murs | +4 murs | +5 murs | 0 |
| Arbalète, Baliste, Mortier, Givre, Alambic, Totem | Tour | prix de la tour | Pose la tour sur un mur | 30 % moins chère | Arrive au niveau 2 | 0 |
| Fosse à pieux | Piège | 8 | 30 dégâts à chaque ennemi qui passe, 1 vague | 40 dégâts, 2 vagues | 50 dégâts, 3 vagues | 0 |
| Huile de lampe | Bonus tours | 10 | Tours +25 % de cadence, 1 vague | 2 vagues | 3 vagues | 0 |
| Résine collante | Piège | 6 | Ralentit de 50 % pendant 2 s, 1 vague | 2,5 s, 2 vagues | 3 s, 3 vagues | 2 |
| Pierre à aiguiser | Bonus tours | 10 | Tours +25 % de dégâts, 1 vague | 2 vagues | 3 vagues | 3 |
| Bandelettes lourdes | Malus ennemis | 10 | Ennemis 20 % plus lents, 1 vague | 2 vagues | 3 vagues | 5 |
| Malédiction des os | Malus ennemis | 12 | Ennemis +20 % de dégâts subis, 1 vague | 2 vagues | 3 vagues | 7 |

Un effet joué entre deux vagues compte à partir de la vague suivante ; joué pendant une vague, cette vague compte. Les ibis volent au-dessus des pièges. Chaque ennemi déclenche un piège une fois par vague.

**Construire son deck** (camp de base, bouton « Deck de cartes ») : 20 cartes exactement, 6 exemplaires au plus par carte, au moins une carte de tour et une carte de murs. Les cartes se débloquent avec le rang d'archéologue (colonne « Rang »). Deck de départ : 6 Pierres taillées, 4 Arbalètes, 2 Givres, 2 Balistes, 1 Mortier, 1 Alambic, 1 Totem, 2 Fosses à pieux, 1 Huile de lampe.

**Améliorer ses cartes** : après chaque victoire, l'atelier de cartes permet d'améliorer une carte du deck. Chaque carte s'améliore 2 fois au plus, et l'amélioration dure toute l'expédition. Graver une relique (la détruire) donne une amélioration de plus.

Tous les réglages (taille du deck, main de départ, cartes par vague, murs de base, prix et effets) sont en haut de `scripts/data/cards.gd`.

## Les tours

| Tour | Prix | Rôle |
|---|---|---|
| Arbalète | 15 | Tir rapide sur un ennemi |
| Baliste | 30 | Gros dégâts, grande portée, lente |
| Mortier | 35 | Dégâts de zone, ne tire pas de près |
| Givre | 20 | Ralentit tous les ennemis à portée |
| Alambic | 25 | Empoisonne, vise d'abord les ennemis sains |
| Totem | 30 | N'attaque pas : les tours voisines tirent 30 % plus vite |

### Améliorer les tours

Clique sur une tour posée (ou survole-la et appuie sur **U**) pour ouvrir son menu d'amélioration.

- **Niveau 2** (60 % du prix de la tour) : dégâts et effets +30 %, portée +10 %.
- **Niveau 3** (100 % du prix) : on choisit une **spécialisation** parmi deux voies.

| Tour | Voie A | Voie B |
|---|---|---|
| Arbalète | Rafale : cadence x2 | Tireur d'élite : dégâts x1,6, portée +40 %, vise le plus résistant |
| Baliste | Harpon : dégâts x1,3, ralentit la cible de 50 % pendant 1,5 s | Perce-rangs : le carreau traverse tous les ennemis sur sa trajectoire |
| Mortier | Obus incendiaires : l'explosion brûle (6 dégâts/s pendant 3 s) | Grand calibre : dégâts x1,5, explosion 50 % plus large, cadence x0,8 |
| Givre | Blizzard : portée x1,4 | Gel profond : ralentit de 70 %, dégâts x3 |
| Alambic | Nuage toxique : empoisonne aussi autour de la cible | Acide : poison x1,5, les empoisonnés subissent +20 % de dégâts |
| Totem | Tambours de guerre : bonus de cadence x1,7 | Totem de rage : tours à portée +25 % de dégâts |

Revendre une tour rend la moitié de tout ce qu'elle a coûté (pose et améliorations). Les chiffres sont dans `scripts/tower_types.gd`.

## Les sprites

Une partie des graphismes est faite de sprites dessinés en vectoriel : les sources sont dans `art/sources/*.svg` et les images utilisées par le jeu dans `art/sprites/*.png` (rendues en taille double pour rester nettes). Les 6 tours (socle, et arme qui pivote pour l'Arbalète, la Baliste et le Mortier), le dessus des murs (désert et glace) et les 11 ennemis (`art/sources/ennemis/`) sont en sprites ; ils servent aussi d'icônes dans la barre de construction, le menu d'amélioration et sur les reliques. Survoler un joker (récompense, marchand, carnet, feu de camp) ouvre une infobulle avec son descriptif et les tours concernées. Le reste est dessiné par code dans `scripts/art.gd` et `scripts/tower_art.gd`.

Pour modifier un sprite : éditer le SVG (Inkscape, ou n'importe quel éditeur vectoriel), puis l'exporter en PNG à 200 % dans `art/sprites/` avec le même nom, ou lancer `node tools/render_svg.js art/sources art/sprites` (et `node tools/render_svg.js art/sources/ennemis art/sprites/ennemis` pour les ennemis). Les ennemis gardent leurs effets dessinés par code par-dessus le sprite : contour d'élite, givre, poison, barre de vie.

## Organisation du code

- `scenes/` : les écrans (camp de base, carnet, améliorations, carte, niveau, récompense, fin). Le camp de base est lancé au démarrage.
- `scripts/run_state.gd` : l'expédition en cours (vies, jokers, score, carte), accessible partout sous le nom `Run`.
- `scripts/profile.gd` : le profil sauvegardé (rang, score cumulé, points répartis), accessible partout sous le nom `Profile`.
- `scripts/map_gen.gd` : création de la carte à embranchements.
- `scripts/level.gd` : un niveau (murs, pathfinding `AStarGrid2D`, vagues, dunes, tempête, affichage).
- `scripts/map_screen.gd`, `scripts/reward_screen.gd`, `scripts/end_screen.gd` : les autres écrans.
- `scripts/data/` : les données à modifier pour équilibrer (biomes, plans des niveaux, ennemis, jokers, reliques, améliorations, cartes).
- `scripts/cards_screen.gd` : l'atelier de cartes après chaque victoire ; `scripts/deck_screen.gd` : la construction du deck au camp de base.
- `scripts/grid.gd` : taille de la grille, conversions case ↔ pixels.
- `scripts/enemy.gd` : un ennemi qui suit son chemin et le recalcule quand la grille change.
- `scripts/tower.gd` : le comportement des tours (tir, zone, ralentissement, poison, soutien).
- `scripts/tower_types.gd` : les chiffres des 6 tours (prix, portée, dégâts, cadence).

Les valeurs à modifier pour tester l'équilibrage (coûts, portée, dégâts, vitesse) sont des constantes en haut de chaque script.

## Version web (téléphone, tablette, navigateur)

Le jeu tourne aussi dans un navigateur, y compris Safari sur iPhone : ouvrir le lien, puis « Partager > Sur l'écran d'accueil » pour le lancer en plein écran comme une app. Tourner le téléphone à l'horizontale.

Contrôles tactiles (`scripts/touch.gd`) :
- toucher = clic (au moment où on lève le doigt) ;
- laisser le doigt = l'infobulle s'affiche ; un appui long (0,5 s) fait un clic droit : retirer un mur ou une tour, annuler une relique ;
- boutons **Vague ▶** et **Vitesse x2** en haut à droite du niveau (remplacent Espace et F).

Les symboles (★ ⚔ ☠ ⚗...) viennent de la police DejaVu Sans fournie dans `art/fonts/`, car le navigateur ne donne pas accès aux polices du système.

Pour refaire l'export : installer les modèles d'export de Godot 4.7, puis `GODOT=/chemin/vers/godot sh tools/export_web.sh`. Le résultat (`build/web`) se publie sur la branche `gh-pages`, servie par GitHub Pages.
