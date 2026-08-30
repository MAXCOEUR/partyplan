# Captures d'écran de l'application

Jeu de captures destiné aux fiches de boutique et au site vitrine. Toutes viennent de
l'application web réelle servie en local, jamais d'une maquette.

## Contenu

| Dossier | Taille | Usage |
|---|---|---|
| `telephone-clair/` | 1290 × 2796 | App Store iPhone 6,7 pouces, Play Store téléphone |
| `telephone-sombre/` | 1290 × 2796 | même chose, thème sombre |
| `bureau-clair/` | 2560 × 1600 | Play Store tablette, aperçus web et presse |
| `bureau-sombre/` | 2560 × 1600 | même chose, thème sombre |

Chaque dossier contient les mêmes neuf écrans, numérotés dans l'ordre du parcours :
connexion, accueil, présences, courses, dépenses, remboursements, discussion, sondage,
invitation.

Les captures du site vitrine en sont dérivées, réduites et converties en WebP, dans
`landing/public/images/app/`.

## Régénérer

Le script recrée les quatre jeux d'un coup. Playwright n'est pas une dépendance du
dépôt — il pèse plus que tout le reste de l'outillage et ne sert qu'ici — donc il
s'installe à côté.

```bash
make up          # base, courriel, application web sur :8080
make api         # API en rechargement à chaud sur :5080

# Un compte et une soirée peuplée sont nécessaires : les captures montrent des données,
# pas des écrans vides.
mkdir -p /tmp/pp-captures && npm --prefix /tmp/pp-captures install playwright
cp tools/captures-boutique.mjs /tmp/pp-captures/
node /tmp/pp-captures/captures-boutique.mjs \
  --email=<compte> --motdepasse=<mot de passe> \
  --evenement=<uuid de la soirée> \
  --sortie=$PWD/docs/captures
```

Le script se copie dans le dossier d'installation parce que Node résout les modules ES
depuis l'emplacement du fichier, et non depuis `NODE_PATH`.

## À savoir

- L'application est servie par le conteneur `web`, compilé en production. Une capture
  prise sur `flutter run` afficherait la bannière de débogage.
- Le thème suit le réglage du système : le script le force par contexte, il n'existe
  pas de bascule dans l'interface.
- Les montants visibles proviennent du jeu de démonstration et tombent juste :
  334,80 € pour cinq participants, soit 66,96 € chacun.
