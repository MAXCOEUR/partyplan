# PartyPlan

> Ta soirée, enfin organisée.

Application d'organisation d'événements entre amis (3 à 20 personnes) : présences,
liste de courses collaborative, dépenses et remboursements, planning.
Remplace le groupe WhatsApp/Snapchat chaotique par un espace structuré.

## Structure du dépôt

Monorepo unique — voir [docs/adr/0001-monorepo.md](docs/adr/0001-monorepo.md).

```
partyplan/
├── api/            API ASP.NET Core 10 (modular monolith) + PostgreSQL
│   ├── src/        Host, modules métier, infrastructure
│   └── tests/      Tests unitaires et d'intégration
├── app/            Application Flutter (Android / iOS / Web)
├── landing/        Site vitrine (statique)
├── infra/          Docker Compose, reverse proxy, scripts d'exploitation
├── docs/           ADR, modèle de domaine, charte graphique, contrat d'API
├── tools/          Génération du client Dart depuis l'OpenAPI, utilitaires
└── .github/        CI
```

## Prérequis

| Outil | Version validée localement |
|---|---|
| .NET SDK | 10.0.302 |
| Flutter | 3.38.9 (stable) |
| Docker + Compose | v2 |
| PostgreSQL | 16+ (via Compose en local) |

## Environnements

| Usage | URL |
|---|---|
| Application (Flutter Web) | https://partyplan.maxencecoeur.fr |
| API | https://api.partyplan.maxencecoeur.fr |
| Fichiers statiques | https://cdn.partyplan.maxencecoeur.fr |

Le temps réel (SignalR) est exposé sous `/hubs` sur le domaine de l'API —
pas de sous-domaine dédié, voir [docs/adr/0003-domaines.md](docs/adr/0003-domaines.md).

## Conteneurs et déploiement

Deux piles Compose, décrites dans [docs/adr/0004-chaine-de-livraison.md](docs/adr/0004-chaine-de-livraison.md) :

| Fichier | Usage |
|---|---|
| `infra/compose/compose.yml` | Développement local. Compile depuis les sources, publie les ports sur l'hôte, pas de TLS. |
| `infra/compose/compose.example.yml` | Production. Consomme les images publiées sur GHCR, reverse proxy Caddy avec certificats automatiques. |

### Local

Tout passe par le `Makefile` — `make aide` liste les cibles.

```bash
make up          # base, courriel, API, web, vitrine
make api         # API en rechargement à chaud
make app         # Flutter sur Chrome, en rechargement à chaud
make reset-db    # base repartie de zéro + jeu de démonstration
make verif       # format, analyse, tests — à passer avant chaque push
```

| Service | Adresse |
|---|---|
| Application | http://localhost:8080 |
| API | http://localhost:5080 |
| Vitrine | http://localhost:8081 |
| Courriels capturés | http://localhost:8025 |

Aucun compte externe n'est nécessaire pour développer : les courriels sont capturés par
Mailpit, les notifications poussées sont journalisées en console, les connexions Google
et Apple sont désactivables. Voir `§13.4` du cahier des charges.

Administrateur de développement amorcé : `admin@partyplan.local` /
`MotDePasseDeDeveloppement`. Ces valeurs sont refusées en production (`RG-ADM-11`).

### Production

```bash
cp infra/compose/.env.example infra/compose/.env   # puis renseigner les secrets
docker compose --env-file infra/compose/.env -f infra/compose/compose.example.yml pull
docker compose --env-file infra/compose/.env -f infra/compose/compose.example.yml up -d
```

Images publiées par l'intégration continue :

```
ghcr.io/<propriétaire>/partyplan-api
ghcr.io/<propriétaire>/partyplan-web
ghcr.io/<propriétaire>/partyplan-landing
```

Étiquettes : `latest` sur `main`, `sha-<empreinte>` par commit, `X.Y.Z` sur tag.
Retour arrière : remettre l'étiquette précédente dans `infra/compose/.env`, puis `pull && up -d`.

Sur une pull request, les images sont construites sans être publiées et déposées comme
artefacts du run :

```bash
gh run download <id> -n image-partyplan-api
docker load -i partyplan-api.tar
```

## Conventions

- Commits : [Conventional Commits](https://www.conventionalcommits.org/fr/) avec périmètre
  (`feat(shopping): ...`, `fix(api): ...`, `chore(infra): ...`).
- Branches : `main` protégée, travail sur `feat/*`, `fix/*`, `chore/*`.
- Tags : `api-v1.2.0`, `app-v1.2.0` — les deux composants se versionnent indépendamment
  bien qu'ils partagent le dépôt.
- Toute décision structurante fait l'objet d'un ADR dans `docs/adr/`.

## Documentation

| Document | Contenu |
|---|---|
| [docs/cahier-des-charges.md](docs/cahier-des-charges.md) | Référence fonctionnelle : exigences numérotées, règles de calcul, modèle de données, API, RGPD, critères d'acceptation |
| [docs/domaine.md](docs/domaine.md) | Synthèse du modèle de domaine |
| [docs/developpement.md](docs/developpement.md) | Mise en route, rechargement à chaud, Rider, Android Studio, émulateur, problèmes courants |
| [docs/roadmap.md](docs/roadmap.md) | **Suivi d’avancement** : toutes les tâches à faire, cochables, groupées par version de publication |
| [docs/brand/charte.md](docs/brand/charte.md) | Identité visuelle |
| [docs/exploitation.md](docs/exploitation.md) | Déploiement, retour arrière, sauvegardes, restauration, supervision |
| [docs/adr/](docs/adr/) | Décisions d'architecture, dont [0005 — identité et administration](docs/adr/0005-identite-et-administration.md) |
