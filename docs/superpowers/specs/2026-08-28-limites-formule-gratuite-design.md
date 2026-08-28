# Limites de la formule gratuite — conception

**But** : la formule gratuite cesse d'être illimitée. Trois événements possédés à la
fois, vingt membres par événement. Un administrateur attribue la formule payante à la
main ; chacun voit la sienne depuis son profil.

**Décidé le 28/08/2026** — `ADR 0008`. Remplace la conception du 25/08/2026, jamais
implémentée.

Périmètre : les limites, leur attribution, leur affichage. **Pas de paiement.**

---

## 1. Ce qui existe déjà

| Élément | Où | État |
|---|---|---|
| `users.premium_until` | schéma initial du 19/08 | en base, jamais lue |
| `User.IsPremium(now)` | `Modules.Users/Domain/User.cs:65` | écrite, aucun appelant |
| `MyProfile.PremiumUntil` | `Modules.Users/Application/AccountService.cs:22` | remontée au client |
| `MemberCount` | `Modules.Events/Application/EventSummary.cs:15` | calculé |
| `TransfererProprieteAsync` | `Modules.Events/Application/AttendanceService.cs:247` | livré |

Aucune migration n'est donc nécessaire, et l'API du profil expose déjà la donnée : il
manque son affichage.

## 2. Frontière de modules

Le module `Events` doit savoir si un compte est abonné. La règle 6 lui interdit la table
`users`. Nouveau contrat, `SharedKernel/Contracts/IFormuleCompte.cs` :

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Formule d'un compte, telle que les autres modules ont besoin de la connaître.
/// <para>
/// Réduite à un booléen : les modules appliquent des quotas, ils n'ont pas à connaître
/// une échéance ni un moyen de paiement. Le jour où le lot 4.1 apportera des cycles de
/// vie datés, ce contrat ne changera pas de forme.
/// </para>
/// </summary>
public interface IFormuleCompte
{
    Task<bool> EstAbonneAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>
    /// Formules de plusieurs comptes, en une requête. Nécessaire pour la liste des
    /// événements : un appel par ligne referait autant de requêtes que de soirées.
    /// Les identifiants inconnus valent « non abonné ».
    /// </summary>
    Task<IReadOnlyDictionary<Guid, bool>> EstAbonneManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);
}
```

Implémenté par `Modules.Users`, qui lit `premium_until` et le compare à `IClock.Now` via
`User.IsPremium`. Enregistré par `UsersModule`. Le module `Events` reçoit l'interface.
`tools/verifier-frontieres-modules.sh` le vérifie en CI.

Les quotas eux-mêmes — 3 et 20 — vivent dans `Events`, avec les compteurs qu'ils bornent.
Une constante nommée par limite, pas de configuration : un quota paramétrable
n'aurait aucun appelant pour le changer.

## 3. Quota d'événements possédés

Point de contrôle unique : `EventService.CreateAsync` (`EventService.cs:92`).

```
COUNT(events)
  WHERE  event_members.user_id = appelant
    AND  event_members.role    = Owner      -- et non events.created_by_user_id
    AND  event_members.removed_at IS NULL
    AND  events.deleted_at IS NULL
    AND  fin_effective > maintenant         -- ends_at, ou starts_at + 12 h (EF-EVT-02)
```

**La propriété se lit sur `event_members.role`, jamais sur `events.created_by_user_id`.**
Les deux existent et ne disent pas la même chose : `created_by_user_id` est le créateur
historique, immuable, tandis que `TransfererProprieteAsync`
(`AttendanceService.cs:277-281`) déplace le rôle `Owner` d'un membre à l'autre sous un
index d'unicité qui garantit un propriétaire actif par événement. Compter le créateur
rendrait le transfert sans effet sur le quota : le cédant resterait débité d'un événement
qu'il ne possède plus, et le repreneur n'en serait jamais crédité. C'est le défaut de la
conception du 25/08, qui comptait `created_by_user_id`.

Refusé si le compte atteint 3 et que l'appelant n'est pas abonné. `DomainError` de
catégorie `Forbidden` (403), code `plan.event_quota_reached`, message nommant le quota et
les deux sorties : attendre la fin d'une soirée, ou passer à la formule payante.

Compte, et ne compte pas :

| Situation | Compte ? | Motif |
|---|---|---|
| Événement à venir dont je suis `Owner` | oui | |
| Événement en cours dont je suis `Owner` | oui | jusqu'à sa fin effective |
| Événement **terminé** | **non** | la place se libère seule — c'est le renversement du 25/08 |
| Événement supprimé | non | libération par anticipation |
| Événement **archivé** mais à venir | oui | l'archivage n'entre pas dans le calcul : seules la fin effective et la suppression libèrent. Le cas est théorique — on n'archive pas une soirée à venir — mais la règle doit trancher plutôt que dépendre d'un `ArchivedAt` que `EF-EVT-09` ne livrera qu'en V1.1 |
| Événement que j'ai quitté après transfert | non | je n'en suis plus `Owner` |
| Événement dont je suis membre sans le posséder | non | rejoindre est illimité |
| Compte abonné | sans objet | quota levé |

**Dépassement toléré** : un transfert de propriété ne vérifie rien, et deux créations
simultanées au bord du quota ne sont pas sérialisées — même motif qu'à l'adhésion,
exposé au §4. Un compte à 3/3 qui
accepte un transfert passe à 4/3 ; ses quatre événements fonctionnent, seule une
cinquième création lui est refusée. `RG-ROLE-02` reste praticable en toutes
circonstances. Vérifié par test.

## 4. Plafond de membres

Point de contrôle unique : `JoinService.RejoindreAsync`, la surcharge privée de la
ligne 107 que les deux publiques appellent — jeton et code court passent donc tous deux
par là.

```
COUNT(event_members) WHERE event_id = … AND removed_at IS NULL   >= 20  → refus
```

Refusé si le plafond est atteint et que le **propriétaire** de l'événement n'est pas
abonné (`EF-PRM-03`). Code `plan.member_limit_reached`, 403.

Trois précautions :

1. **L'idempotence de `RG-INV-05` passe avant le quota.** Un membre déjà présent qui
   rejoue sa requête réussit sans toucher au compteur. Vérifier le quota d'abord ferait
   échouer une adhésion valide sur un simple doublon de requête.
2. **La course est acceptée, et documentée comme telle.** Deux adhésions arrivant à
   19/20 dans la même poignée de millisecondes peuvent produire 21 membres. Aucune
   garantie transactionnelle n'est tentée : `IEventsDbContext` n'expose pas `Database`,
   et l'écriture conditionnelle qui protège `RG-CRS-01`
   (`ShoppingService.cs:299-307`) ne se transpose pas à un décompte de lignes.
   Élargir le contrat du module pour un plafond commercial serait disproportionné.
   La conséquence d'un franchissement est nulle : `RG-PRM-02` interdit de dégrader
   l'existant, donc personne ne serait exclu, et un dépassement est déjà toléré par
   conception après un transfert de propriété. Ce quota borne une offre, il ne protège
   ni un cloisonnement ni un calcul financier — les deux seuls endroits où le dépôt paie
   le prix d'une garantie forte.
3. **Les accompagnants ne comptent pas.** `EF-PRES-06` en autorise dix par membre ; les
   inclure ferait franchir le plafond après une déclaration de présence, donc
   rétroactivement, ce que `RG-PRM-02` interdit. `RG-PRES-04` sépare déjà les deux
   décomptes.

L'aperçu public d'invitation (`JoinService.ApercuAsync`, ligne 192) porte un booléen
`Complet`. Un invité voit « complet » avant de créer un compte. Le nombre de participants
figure déjà dans l'aperçu de `RG-INV-04` : rien de nouveau n'est exposé.

## 5. Attribution par un administrateur — `EF-PRM-04`

```
PUT    /v1/admin/users/{userId}/plan   { premiumUntil, reason }  → 204
DELETE /v1/admin/users/{userId}/plan   { reason }                → 204
```

Réservés à `PlatformAdmin`. `Support` reçoit 403 : `RG-ADM-05` le borne à la consultation
et au dépannage, et offrir un abonnement n'est ni l'un ni l'autre.

`premiumUntil` est **obligatoire** et doit être dans le futur. Pas de formule payante sans
terme : le lot 4.1 gérera les renouvellements, et une échéance nulle se traduirait par une
date en 2099 qu'il faudrait démêler plus tard. Motif obligatoire, comme la suspension.

Une action d'audit, ajoutée à `AdminAuditActions` :

```csharp
public const string PlanChanged = "user.plan_changed";
```

Une seule et non deux : accorder et retirer sont le même geste, la nouvelle échéance
distingue l'un de l'autre. L'entrée porte l'ancienne et la nouvelle valeur. Ajout seul par
`RG-ADM-06`, `NF-SEC-08` en garantit l'immuabilité jusqu'au déclencheur.

Idempotence : réappliquer la même échéance renvoie 204 sans écrire d'audit — sinon un
double clic dans le back-office produirait deux lignes identiques dans un journal
inaltérable.

`RG-ADM-01` reste intacte : une formule est un attribut de compte, du même ordre que le
rôle plateforme. Aucun contenu d'événement n'est lu.

## 6. Côté application

**Fiche compte du back-office** — la formule et l'action pour la changer. Boîte de
dialogue : échéance (raccourcis 1 mois, 1 an, date libre), motif. Visible du seul
`PlatformAdmin`.

**Profil — `EF-PRM-05`** — une ligne « Formule » : *Gratuit* ou *Premium jusqu'au
28/09/2026*, en JJ/MM/AAAA. La donnée arrive déjà de `MyProfile`.

**Accueil, en formule gratuite** — le quota consommé, « 2 soirées sur 3 ». Une limite
qu'on ne découvre qu'au refus est une mauvaise surprise. Masqué pour un abonné.

**Au refus** — le message du serveur, tel quel, dans le composant d'erreur existant.

**Pas d'écran Premium, pas de bouton d'achat.** Aucun encaissement n'existe ; le produit
s'interdit déjà les boutons condamnés.

Composant réutilisable pour le quota, jetons du design system, aucune couleur ni
espacement en dur. États chargement, vide et erreur comme partout ailleurs.

## 7. Unités

| Unité | Rôle | Dépend de |
|---|---|---|
| `IFormuleCompte` | contrat de frontière | — |
| `Users.Application.FormuleCompte` | l'implémente sur `premium_until` | `IUsersDbContext`, `IClock` |
| `Users.Application.PlanAdminService` | attribuer, retirer, journaliser | `IUsersDbContext`, `IClock`, `IAuditLog` |
| `Users.Endpoints.AdminPlanEndpoints` | les deux routes | `PlanAdminService` |
| `Events.Application.QuotaEvenements` | compte et décide | `IFormuleCompte`, contexte `Events` |
| `Events.Application.EventService` | applique à la création | `QuotaEvenements` |
| `Events.Application.JoinService` | applique à l'adhésion | `QuotaEvenements` |

`QuotaEvenements` est une unité à part et non deux méthodes dispersées : les deux règles
partagent la lecture de la formule, et un seul objet les rend testables sans base — la
formule s'injecte, les compteurs se passent en paramètre.

## 8. Tests

TDD, test rouge d'abord. `NF-QUAL-01` ne s'applique pas — rien ici n'est financier — mais
chaque branche de refus est couverte : un quota mal borné ouvre ou ferme le produit à
tort.

**Unitaire, `QuotaEvenements`** — frontière exacte à 2, 3 et 4 événements ; à 19, 20 et
21 membres ; abonné au-delà des deux ; abonnement expiré traité comme gratuit ; échéance
au jour près.

**Intégration, quota d'événements** — trois créations passent, la quatrième renvoie 403 et
le code attendu ; une soirée terminée rend une place sans rien supprimer ; la supprimer la
rend aussi ; en quitter une après transfert la rend ; un abonné en crée dix ; être membre
de dix événements d'autrui ne consomme rien ; **un compte à 4/3 après transfert garde ses
quatre événements pleinement utilisables** — `RG-PRM-02`, `RG-PRM-03`.

**Intégration, plafond de membres** — la 21ᵉ adhésion renvoie 403 ; un rejeu d'un membre
existant réussit à 20/20 (`RG-INV-05` avant le quota) ; le plafond suit le propriétaire,
pas l'arrivant ; dix accompagnants ne consomment aucune place ; l'aperçu public annonce
« complet ».

**Intégration, attribution** — un `PlatformAdmin` accorde puis retire ; `Support` et
`User` reçoivent 403 ; l'échéance passée est refusée ; le motif manquant est refusé ;
chaque changement effectif écrit une ligne d'audit, un rejeu identique n'en écrit pas ;
la ligne d'audit résiste à `UPDATE` et `DELETE`.

**Frontières** — `tools/verifier-frontieres-modules.sh` reste vert : `Events` ne référence
jamais `Modules.Users`.

**Application** — le profil affiche les deux états ; l'accueil affiche « 2 sur 3 » en
gratuit et rien en abonné ; le message de refus est celui du serveur.

## 9. Hors périmètre

Encaissement, achats intégrés Google Play et App Store, cycle de vie d'abonnement, écran
Premium, archives limitées à 3 mois, et toutes les fonctions du lot 4.2 — modèles,
export PDF, sondages avancés, groupes de partage multiples.

## 10. Ordre d'exécution

1. Cahier des charges et `ADR 0008` — **faits avant le code**, sans quoi le code
   contredit un document qu'on lit.
2. `IFormuleCompte` et son implémentation dans `Users`.
3. `QuotaEvenements` et ses tests unitaires.
4. Quota à la création d'événement.
5. Plafond à l'adhésion, et « complet » sur l'aperçu.
6. Attribution par l'administrateur, avec audit.
7. Affichage : profil, accueil, fiche du back-office.
8. Feuille de route.
