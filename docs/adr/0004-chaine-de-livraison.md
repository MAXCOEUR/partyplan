# ADR 0004 — Chaîne de livraison par images conteneur

- Date : 19/08/2026
- Statut : accepté

## Contexte

Trois livrables déployables (API, application Web, site vitrine) dans un dépôt unique
(ADR 0001), un serveur cible unique, un développeur unique. Il faut un mécanisme de
déploiement reproductible et un retour arrière immédiat.

## Décision

1. Chaque livrable est empaqueté en image OCI, construite exclusivement par
   l'intégration continue — jamais sur le serveur de production.
2. Les images sont publiées sur GitHub Container Registry :
   `ghcr.io/<propriétaire>/partyplan-{api,web,landing}`.
3. Étiquetage : `latest` sur la branche par défaut, `sha-<empreinte>` sur chaque commit,
   et la version issue du tag (`api-v1.2.0` → `1.2.0`).
4. Le déploiement consiste à modifier une étiquette dans `infra/compose/.env`, puis à
   exécuter `docker compose pull && up -d`. Le retour arrière consiste à remettre
   l'étiquette précédente.
5. Sur une pull request, l'image est construite mais **non publiée** : elle est déposée
   comme artefact du run (archive `docker save`), téléchargeable et chargeable en local
   par `docker load`.

## Justification

- Publier depuis une pull request exposerait un jeton d'écriture sur le registre à du
  code non revu. L'artefact permet de tester l'image sans ce risque.
- L'étiquette `sha-<empreinte>` garantit qu'une version déployée est traçable jusqu'au
  commit, ce que `latest` seul ne permet pas.
- Construire sur le serveur de production consommerait sa mémoire et rendrait le
  résultat dépendant de l'état de la machine.

## Choix d'architecture matérielle

Une seule plateforme, `linux/amd64`. La compilation de Flutter Web sous émulation
QEMU arm64 multiplie la durée du job par environ cinq sans bénéfice, le serveur cible
étant x86_64. À réexaminer si l'hébergement change.

## Reverse proxy

Caddy, pour l'obtention et le renouvellement automatiques d'un certificat par nom en
challenge HTTP-01, conformément à l'ADR 0003. Aucun accès à l'API du registrar n'est
requis, contrairement à un certificat joker.

## Conséquences

- Le fichier `infra/compose/compose.example.yml` ne compile rien : il consomme les
  images publiées. La compilation locale reste dans `infra/compose/compose.yml`.
- Un secret ajouté au déploiement doit être renseigné dans `infra/compose/.env.example`,
  sans valeur, sous peine d'être découvert au premier démarrage en production.
