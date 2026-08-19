# ADR 0002 — API en modular monolith

- Date : 19/08/2026
- Statut : accepté

## Décision

Une seule API, une seule base PostgreSQL, découpée en modules aux frontières explicites.

```
PartyPlan.Api                 host : endpoints, hubs SignalR, DI, authentification
PartyPlan.SharedKernel        types transverses, résultats, erreurs métier
PartyPlan.Infrastructure      EF Core, migrations, Npgsql, stockage fichiers, e-mail
PartyPlan.Modules.Auth
PartyPlan.Modules.Users
PartyPlan.Modules.Events      événements, membres, invitations
PartyPlan.Modules.Shopping    listes et articles
PartyPlan.Modules.Expenses    dépenses, participants
PartyPlan.Modules.Settlements algorithme de simplification des remboursements
PartyPlan.Modules.Tasks
PartyPlan.Modules.Polls
PartyPlan.Modules.Messages
PartyPlan.Modules.Notifications
PartyPlan.Modules.Administration  back-office : comptes, rôles, journal d'audit
```

Le module `Administration` a été ajouté le 19/08/2026 avec l'ADR 0005. Il agit sur des
comptes, jamais sur le contenu d'un événement (`RG-ADM-01`).

## Règles de frontière

- Un module n'accède jamais aux tables d'un autre module directement.
  La communication passe par une interface publique exposée par le module propriétaire.
- **Mise en œuvre** : chaque module déclare une interface de persistance
  (`IEventsDbContext`, `IUsersDbContext`, …) ne listant que ses propres tables. Le
  contexte unique de l'Infrastructure implémente toutes ces interfaces, et l'injection
  ne fournit à chaque module que la sienne. La frontière devient ainsi une contrainte
  de compilation, non une consigne.
- La dépendance va de l'Infrastructure vers les modules, jamais l'inverse. Le contrôle
  est automatisé : `./tools/verifier-frontieres-modules.sh`, exécuté en intégration
  continue.
- `Settlements` dépend de `Expenses` en lecture seule via contrat.
- Aucune référence circulaire entre modules — vérifiée en CI.
- Les migrations EF Core sont centralisées dans `Infrastructure` (une seule base).

## Conséquences

Pas de microservices. Si un module devient un point de contention, il est extractible
car ses dépendances entrantes sont limitées à son interface publique.
