# ADR 0001 — Dépôt unique (monorepo)

- Date : 19/08/2026
- Statut : accepté

## Contexte

Le projet comporte quatre livrables : une API ASP.NET Core, une application Flutter
(Android / iOS / Web), un site vitrine et une couche d'infrastructure Docker.
Le développement est assuré par une seule personne.

## Décision

Un seul dépôt Git contenant l'ensemble des livrables.

## Justification

1. Un changement de contrat d'API impacte simultanément `api/` et `app/`. Un dépôt
   unique permet un commit atomique cohérent, sans ordre de merge à orchestrer.
2. Le client Dart est généré depuis l'OpenAPI de l'API. En dépôts séparés, il
   faudrait publier un package privé versionné à chaque évolution.
3. Le fichier Compose référence l'API, le web et la base : il doit vivre avec eux.
4. Le choix d'un modular monolith côté API rendrait incohérent un découpage du dépôt.
5. Aucun des motifs justifiant le multi-dépôt n'est présent : pas d'équipes distinctes,
   pas de cycles de release indépendants, pas d'ouverture partielle du code.

## Conséquences

- La CI doit filtrer par chemin (`paths:`) pour ne pas rejouer l'ensemble des jobs
  à chaque commit.
- Les versions de l'API et de l'application sont taguées séparément
  (`api-vX.Y.Z`, `app-vX.Y.Z`) malgré le dépôt commun.
- Extraction ultérieure possible sans perte d'historique via `git subtree split`.

## Alternative écartée

Quatre dépôts (`partyplan-api`, `partyplan-app`, `partyplan-landing`,
`partyplan-infra`). Écartée : coût de coordination sans bénéfice à un seul développeur.
