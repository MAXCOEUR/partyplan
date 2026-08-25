# DESIGN.md — contrat de design de PartyPlan

Document de référence, lu avant toute intervention visuelle. La palette et la typographie
viennent de `docs/brand/charte.md` : **ce document les applique, il ne les redéfinit pas.**

## Lecture de design

Application de soirées entre amis, pour des particuliers, sur téléphone d'abord et
navigateur ensuite. Registre **convivial et non applicatif d'entreprise** (`§10.3` du
cahier des charges). Mode **préservation** : la marque est violette et le reste.

## Les trois cadrans

| Cadran | Valeur | Motif |
|---|---|---|
| `DESIGN_VARIANCE` | 6 | Consumer social, mais l'écran d'événement reste une coquille à onglets stable : la variance vit dans la composition, jamais dans la navigation. |
| `MOTION_INTENSITY` | 5 | Discret et utile. Une soirée se consulte vingt fois par jour : une animation par geste fatiguerait. |
| `VISUAL_DENSITY` | 4 | Aéré. Les écrans financiers montent à 6 localement, les montants ayant besoin de densité. |

## Décisions verrouillées

- **Une seule teinte d'accent** : le violet `#6C5CE7`. Le rose `#FF4D8D` est la couleur
  *secondaire*, réservée aux dettes et aux gestes chauds. Aucune troisième teinte.
- **Une seule famille de rayons** : 8 / 12 / 20, et `pill` pour les éléments capsule.
- **Une seule police** : Poppins, embarquée dans `assets/fonts/`, quatre graisses.
- **Chiffres tabulaires obligatoires** sur tout montant : sans eux, une colonne de sommes
  semble bouger d'une ligne à l'autre.
- **Profondeur par l'échelle de surfaces**, jamais par des élévations Material multiples.
  En clair, une ombre unique et très douce ; en sombre, une surface plus claire et
  **aucune ombre** — une ombre sur fond sombre ne se voit pas.
- **Voix** : tutoiement, phrases courtes, aucun point d'exclamation dans les erreurs.
  Jamais de tiret cadratin dans une chaîne d'interface.

## Journal des décisions

| Date | Décision |
|---|---|
| 25/08/2026 | Échelle de surfaces complète sur cinq niveaux. Elle était écrasée à deux, ce qui rendait toute l'application plate. |
| 25/08/2026 | Les cartes ne sont plus bordées en thème clair. Une bordure sur chaque carte, empilée trois ou quatre fois par écran, donnait une pile de boîtes à liseré gris — le principal motif de laideur. |
| 25/08/2026 | Squelettes de chargement. La justification d'origine (« pas de squelette tant que les écrans réels n'existent pas ») a expiré : ils existent. |
| 25/08/2026 | Couche d'animation discrète : retour au toucher, et apparition en cascade des listes. Rien d'autre. |
| 26/08/2026 | Le rail de navigation reçoit enfin un thème. Sans lui, il retombait sur `secondaryContainer` — le rose — et la navigation latérale était magenta pendant que la barre basse était violette, sur le même écran. |
| 26/08/2026 | Le rose quitte l'avancement des courses, l'étiquette de prise en charge et l'origine des dépenses. Il ne reste que sur l'argent dû et la pastille de non-lus, seule sollicitation de la navigation. |
| 26/08/2026 | Les listes de choix rendent leurs options en neutre : seule la réponse retenue porte sa couleur. Cinq options en cinq couleurs mettaient cinq accents sur un écran. |
| 26/08/2026 | La discussion passe en bulles, les miennes à droite, largeur bornée par les contraintes reçues et non par la fenêtre. |
| 26/08/2026 | Logo dessiné en SVG, décliné en favicon, icônes web et lanceur Android. Les icônes de Flutter par défaut ont disparu. |

## Ce qui ne change jamais sans accord explicite

La structure de navigation et l'ordre des onglets, le pictogramme et la teinte de marque,
l'ordre des champs de formulaire, et le texte des mentions légales.
