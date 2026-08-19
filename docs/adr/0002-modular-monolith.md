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
- **Contrats inter-modules** : lorsqu'un module doit en solliciter un autre, l'interface
  est déclarée dans `PartyPlan.SharedKernel/Contracts` et implémentée par le module
  propriétaire. Deux modules ne se référencent jamais directement. Ce répertoire ne
  contient que des interfaces et des types de données — aucune logique — et chaque
  contrat nomme son module propriétaire dans sa documentation.

  Contrats existants : `IUserDirectory` (Users), `IAuditLog` et `AdminAuditActions`
  (Administration), `IPasswordHasher`, `IPasswordPolicy`, `ITokenService` (Auth),
  `IPasswordResetTrigger` (Users), `IEmailSender`, `IAvatarStorage` (Infrastructure).

## Amendement du 19/08/2026 — Auth et Users

Le module `Auth` ne possède aucune table. Le compte, les sessions et les jetons à usage
unique appartiennent à `Users`.

Motif : l'authentification et le compte sont le même agrégat. Les séparer aurait imposé
un contrat inter-modules à chaque connexion — donc à chaque requête — pour aucun
bénéfice de découplage. `Auth` conserve les mécanismes purs, sans persistance : hachage
Argon2id, politique de mot de passe, émission des jetons. Ils sont ainsi testables sans
base, ce qui est précisément ce que l'on veut d'un composant cryptographique.
- `Settlements` dépend de `Expenses` en lecture seule via contrat.
- Aucune référence circulaire entre modules — vérifiée en CI.
- Les migrations EF Core sont centralisées dans `Infrastructure` (une seule base).

## Conséquences

Pas de microservices. Si un module devient un point de contention, il est extractible
car ses dépendances entrantes sont limitées à son interface publique.
