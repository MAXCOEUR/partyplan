# Socle Premium — conception

**But** : une formule payante existe, elle est attribuable, et elle lève une limite
réelle. Sans paiement : l'encaissement appartient au lot 4.1, ce document lui prépare
le terrain sans le préempter.

**Décidé le 25/08/2026.** Limite de la formule gratuite : **3 événements créés**.
Premium : illimité. Seule la suppression libère une place. L'attribution passe par le
back-office.

---

## 1. Ce que cela change au cahier des charges

`RG-PRM-03` dit aujourd'hui : *« Aucune fonction du MVP ne devient payante
rétroactivement. »* Créer un événement est une fonction du MVP. Passé le troisième,
la création devient payante. **La règle devient donc fausse telle qu'écrite.**

Elle est réécrite, et un `ADR 0008` porte la décision — comme l'`ADR 0007` l'a fait pour
le retrait de la double authentification. Contourner une règle en la laissant écrite est
pire que la changer : le prochain lecteur croit la garantie encore valable.

Nouvelle formulation retenue :

> `RG-PRM-03` Une fonction déjà utilisée ne se ferme jamais. Un événement existant reste
> intégralement utilisable quelle que soit la formule : consultable, modifiable, ses
> dépenses et ses remboursements accessibles. Seule la **création d'un nouvel** événement
> au-delà du quota est refusée.

`RG-PRM-01` change aussi de contenu : les limites de la formule gratuite deviennent
« 3 événements créés », les limites « 20 participants » et « archives 3 mois » restant au
lot 4.1 telles quelles.

`RG-PRM-02` est inchangée et reste vraie : l'atteinte d'une limite ne dégrade jamais un
événement en cours.

## 2. Où vit la formule

**Un module dédié `Subscriptions`.** Trois options ont été pesées :

| Option | Retenue ? | Motif |
|---|---|---|
| Module `Subscriptions` | **oui** | Le lot 4.1 y ajoutera Google Play, App Store, renouvellement, expiration, remboursement, rétablissement d'achat. Ce sont des cycles de vie datés, pas un booléen. |
| Colonne sur `users` | non | Plus rapide aujourd'hui. Mais la table sera nécessaire de toute façon, et la migration se fera alors sur des données de production. |
| Drapeau de configuration | non | Ne permet pas d'attribuer la formule à une personne, donc pas d'éprouver la limite. |

Douzième module, à ajouter à `ModuleAssemblies.All`.

### Table

```
subscriptions
  id            uuid       pk
  user_id       uuid       not null, unique
  plan          text       not null   -- « free » | « premium »
  granted_by    uuid       null       -- compte administrateur ayant accordé
  granted_at    timestamptz not null
  expires_at    timestamptz null      -- null = sans terme ; le lot 4.1 le renseignera
  updated_at    timestamptz not null
```

`user_id` est unique : une personne a une formule, pas un historique de formules. Le lot
4.1 ajoutera une table d'événements d'abonnement s'il en a besoin — l'anticiper ici serait
deviner la forme du paiement.

L'absence de ligne vaut `free`. Aucune migration de données n'est donc nécessaire, et un
compte créé ensuite n'a rien à initialiser.

### Contrat public

```csharp
namespace PartyPlan.SharedKernel.Contracts;

public interface ISubscriptionStatus
{
    Task<Formule> ObtenirAsync(Guid userId, CancellationToken cancellationToken);
}

/// <param name="Premium">Vrai si la formule payante est active à cet instant.</param>
/// <param name="EvenementsMaximum">
/// Nombre d'événements créés simultanément autorisés, ou null pour « sans limite ».
/// </param>
public sealed record Formule(bool Premium, int? EvenementsMaximum);
```

La valeur du quota vit dans `Subscriptions` et voyage par le contrat. Le module `Events`
ne connaît pas le chiffre 3 : il connaît « le quota est atteint ».

## 3. Comment la limite s'applique

`EventService.CreateAsync` fait deux choses avant de créer :

1. compte ses propres événements — `created_by_user_id = appelant` et `deleted_at IS NULL` ;
2. demande la formule à `ISubscriptionStatus`.

Si `EvenementsMaximum` est non nul et le compte atteint, la création est refusée par une
`DomainError` de type `RuleViolation` (422), de code `event.quota_reached`, dont le message
nomme le quota et la sortie : supprimer un événement, ou passer Premium.

Chaque module lit sa propre table : `Events` compte des événements, `Subscriptions` lit des
abonnements. La règle 6 est respectée sans exception ni contournement.

**Ce qui compte pour le quota** et ce qui ne compte pas :

| Situation | Compte ? | Pourquoi |
|---|---|---|
| Événement créé, vivant | oui | |
| Événement supprimé (`deleted_at`) | non | C'est la seule libération, par décision du 25/08/2026 |
| Événement **archivé** | **oui** | Décision explicite : l'archivage ne libère pas de place |
| Événement dont on est membre sans l'avoir créé | non | Sinon rejoindre les soirées de ses amis consommerait son propre quota, ce qui punirait exactement l'usage recherché |
| Événement passé, non archivé | oui | |

Le tarif de cette décision est écrit ici pour qu'il ne se découvre pas plus tard :
**supprimer un événement détruit ses dépenses et ses remboursements**. Quelqu'un au quota
qui veut créer une nouvelle soirée efface donc l'historique financier de la précédente.
L'archivage aurait libéré la place en conservant l'historique ; il a été écarté sciemment.

## 4. Attribution

Deux endpoints d'administration, réservés au `PlatformAdmin` :

```
POST   /v1/admin/users/{userId}/premium     → 204
DELETE /v1/admin/users/{userId}/premium     → 204
```

Idempotents tous les deux : accorder à un abonné ne fait rien, retirer à un non-abonné ne
fait rien. Le back-office est manipulé à la main, un 409 sur un double clic n'apprendrait
rien à personne.

Deux actions d'audit s'ajoutent à `AdminAuditActions`, en ajout seul (règle 4) :

```csharp
public const string PremiumGranted = "user.premium_granted";
public const string PremiumRevoked = "user.premium_revoked";
```

`RG-ADM-01` reste intacte : accorder une formule ne donne aucun accès au contenu d'un
événement. C'est un attribut de compte, du même ordre que le rôle plateforme.

## 5. Ce que voit l'utilisateur

- **Au profil** : sa formule, en une ligne. « Gratuit — 2 soirées créées sur 3 » ou
  « Premium — soirées illimitées ». Le compte est affiché parce qu'une limite invisible
  jusqu'au refus est une mauvaise surprise.
- **Au refus** : le message du serveur, tel quel. Il nomme le quota et les deux sorties.
- **Pas d'écran Premium, pas de parcours d'abonnement.** Ils appartiennent au lot 4.1, et
  proposer un bouton d'achat sans encaissement serait un bouton condamné — le produit
  s'interdit déjà ceux-là pour la connexion Google.

## 6. Frontières et unités

| Unité | Rôle | Dépend de |
|---|---|---|
| `Subscriptions.Domain.Subscription` | l'entité | — |
| `Subscriptions.Application.SubscriptionService` | lire, accorder, révoquer ; implémente `ISubscriptionStatus` | son `DbContext`, `IClock`, `IIdGenerator`, `IAuditLog` |
| `Subscriptions.Endpoints.PremiumEndpoints` | les deux routes d'administration | `SubscriptionService` |
| `Events.Application.EventService` | applique le quota | `ISubscriptionStatus` (contrat) |
| Profil, côté application | affiche la formule et le compte | un `GET /v1/me/plan` |

`GET /v1/me/plan` est porté par `Subscriptions` et non par le module `Users`, bien que la
route commence par `/me` : la table lui appartient. C'est le même motif que
`/me/devices`, porté par `Notifications`.

## 7. Tests

Le domaine financier exige 100 % des branches (`NF-QUAL-01`) ; le quota n'est pas
financier mais il décide d'un refus, donc chaque branche est couverte.

**Intégration** — le quota :
- trois créations réussissent, la quatrième est refusée en 422 avec le code attendu ;
- supprimer un événement autorise une nouvelle création ;
- **archiver n'autorise pas** une nouvelle création — le test qui grave la décision ;
- un compte Premium crée un quatrième, un cinquième, un dixième événement ;
- être membre de dix événements créés par d'autres ne consomme pas son quota ;
- un événement existant reste consultable et modifiable une fois le quota atteint
  (`RG-PRM-02`, `RG-PRM-03` réécrite).

**Intégration** — l'attribution :
- un `PlatformAdmin` accorde puis révoque ; les deux appels sont idempotents ;
- un compte ordinaire reçoit 403 sur les deux routes ;
- chaque appel écrit une ligne d'audit, et aucune n'est modifiable.

**Unitaire** :
- `Formule` sans terme, avec terme futur, avec terme passé — un abonnement expiré
  redevient gratuit sans intervention.

**Application** :
- le profil affiche « x sur 3 » en gratuit, « illimité » en Premium ;
- le message de refus est affiché tel qu'il vient du serveur.

## 8. Hors périmètre

Encaissement, achats intégrés, cycle de vie d'abonnement, écran Premium, modèles
d'événements, et toutes les fonctions du lot 4.2. Le présent document ne livre que le
socle : une formule, une attribution, une limite.

## 9. Ordre d'exécution

1. `ADR 0008` et réécriture de `RG-PRM-01` et `RG-PRM-03` au cahier des charges — avant
   le code, faute de quoi le code contredit un document que quelqu'un lit.
2. Module `Subscriptions` : entité, contexte, migration, service, contrat.
3. Endpoints d'administration et audit.
4. Quota dans `EventService`.
5. `GET /v1/me/plan` et l'affichage au profil.
6. Feuille de route.
