# Déclencheurs de notifications — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUISE — `superpowers:subagent-driven-development`
> (recommandée) ou `superpowers:executing-plans` pour dérouler ce plan tâche par tâche.
> Les étapes sont des cases à cocher (`- [ ]`).

**But** : quelqu'un reçoit enfin quelque chose. Le transport est livré ; aujourd'hui
aucune notification ne part jamais.

**Architecture** : `IFileNotifications` enfile dans la transaction de l'action, sur le
motif d'`IJournalActivite` livré au lot 1.10. Les rappels temporels sont calculés par le
module qui détient la donnée, derrière `IPlanificateurRappels`, et un `BackgroundService`
unique orchestre planification puis envoi. Une colonne `dedup_key` unique rend le
balayage rejouable.

**Pile** : ASP.NET Core 10, EF Core 10, PostgreSQL, Flutter 3.38, Riverpod, xUnit,
`flutter_test`. Aucune dépendance nouvelle.

**Spec** : `docs/superpowers/specs/2026-08-26-notifications-declencheurs-design.md` — à
lire avant la première tâche.

## Contraintes globales

- **TDD sans exception.** Test écrit, exécuté rouge, puis implémentation.
- **Le périmètre d'événements n'est pas amorcé hors requête HTTP.** Le filtre global
  s'appuie sur `IEventScope`, et un balayage en tâche de fond lirait **zéro ligne**.
  L'ordonnanceur ouvre donc `scope.AllowTemporarily(eventId)` autour de chaque
  planification : le garde reste actif, borné à un événement à la fois. Seule la lecture
  des événements à venir, dans le module Events, emploie `IgnoreQueryFilters` — un seul
  endroit, documenté.
- **`IClock` et jamais `DateTimeOffset.Now`.** Un rappel « J-3 » ne se teste pas en
  attendant trois jours.
- **Une seule instance** (`RG-RT-04`). Le `dedup_key` protège la planification, pas
  l'envoi : deux instances enverraient tout en double.
- **`SendAsync` ne lève jamais**, et `SentAt` est horodaté même en cas d'échec — sinon la
  boucle réessaie indéfiniment.
- **Sans clé FCM, tout fonctionne** et les notifications se lisent en console
  (`NF-DEV-04`, règle 5).
- **Frontières de modules** (règle 6) : contrat public uniquement, vérifié par
  `make frontieres`.
- **Cloisonnement** : chacun ne lit que ses notifications ; un `PlatformAdmin` non plus
  (`RG-ADM-01`).
- **Montants** : `decimal` en C#, centimes entiers aux frontières de contrat.
- **Aucune chaîne en dur** dans un écran (`NF-I18N-01`) ; aucun jeton de design en dur.
- **`NF-DEV-10`** : aucun test n'appelle FCM. La frontière substituée est `IPushSender`.
- Commits conventionnels : `feat(notifications):`. `make verif` avant chaque commit.
- Cocher `docs/roadmap.md` **au moment du commit**.

---

## Tâche 1 : `dedup_key` et `EF-NOT-10`

**Fichiers :**
- Modifier : `docs/cahier-des-charges.md` (§5.12)
- Modifier : `api/src/PartyPlan.Modules.Notifications/Domain/Notification.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/Persistence/Configurations/RemainingModulesConfiguration.cs`
  (`NotificationConfiguration`, ligne 229)
- Créer : une migration EF
- Test : `api/tests/PartyPlan.IntegrationTests/FileNotificationsTests.cs`

**Interfaces :**
- Produit : `Notification.DedupKey` (`string`), unique en base ; `NotificationCategories.Activity`
  déjà déclarée sert `EF-NOT-10`.

- [ ] **Étape 1 : Ajouter `EF-NOT-10` au cahier des charges**

Après la ligne `EF-NOT-09` du tableau du §5.12 :

```markdown
| EF-NOT-10 | P0 | Notifier l'activité de l'événement : article pris en charge, message posté. Regroupée par RG-NOT-02. |
```

Et compléter `RG-NOT-02` pour qu'elle nomme la catégorie qu'elle plafonne :

```markdown
**RG-NOT-02** — Les notifications d'activité (`EF-NOT-10` : article pris, message) sont
regroupées : au maximum une notification par événement, par destinataire et par tranche
de 15 minutes. Sans ce plafond, une liste de courses remplie à plusieurs produirait une
notification par article.
```

- [ ] **Étape 2 : Écrire le test d'unicité**

```csharp
[Fact]
public async Task Deux_notifications_de_meme_cle_ne_coexistent_pas()
{
    // Le balayage tourne toutes les minutes : sans cette contrainte, un rappel J-3
    // partirait vingt fois par heure.
    await using var essai = ...;

    await fixture.WithDatabaseAsync(async db =>
    {
        db.Notifications.Add(Nouvelle("cle-unique"));
        await db.SaveChangesAsync();
    });

    await Should.ThrowAsync<DbUpdateException>(async () =>
        await fixture.WithDatabaseAsync(async db =>
        {
            db.Notifications.Add(Nouvelle("cle-unique"));
            await db.SaveChangesAsync();
        }));
}
```

- [ ] **Étape 3 : Lancer, vérifier l'échec** — la propriété n'existe pas.

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FileNotificationsTests
```

- [ ] **Étape 4 : Ajouter la propriété et la contrainte**

Dans `Notification` :

```csharp
/// <summary>
/// Clé d'unicité de la notification. Forme :
/// <c>{eventId}:{categorie}:{destinataire}:{occurrence}</c>.
/// <para>
/// Le doublon est refusé par la base et non par l'application : le balayage tourne
/// toutes les minutes, et vérifier puis écrire laisserait précisément la fenêtre
/// qu'il exploiterait. C'est ce qui rend la planification rejouable.
/// </para>
/// </summary>
public string DedupKey { get; set; } = string.Empty;
```

Dans `NotificationConfiguration` :

```csharp
builder.Property(n => n.DedupKey).HasMaxLength(200).IsRequired();
builder.HasIndex(n => n.DedupKey).IsUnique();
```

- [ ] **Étape 5 : Créer la migration**

```bash
cd api && dotnet ef migrations add CleDeDeduplicationDesNotifications \
  --project src/PartyPlan.Infrastructure --startup-project src/PartyPlan.Api
```

La table est vide en pratique (aucune notification n'a jamais été créée), donc aucune
reprise de données n'est nécessaire. Le vérifier avant de conclure.

- [ ] **Étape 6 : Lancer, vérifier le vert**, puis `make frontieres`.

- [ ] **Étape 7 : Commit**

```bash
git add docs/cahier-des-charges.md api/
git commit -m "feat(notifications)!: clé de déduplication, et EF-NOT-10

RG-NOT-02 plafonnait une notification d'activité qu'aucun EF-NOT ne créait :
la règle est complétée et la notification déclarée, plutôt que de laisser une
règle morte comme schedule.changed l'a été après l'abandon du planning.

Le doublon est refusé par la base : un balayage à la minute exploiterait la
fenêtre qu'une vérification applicative laisse ouverte."
```

---

## Tâche 2 : `IFileNotifications`

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IFileNotifications.cs`
- Créer : `api/src/PartyPlan.Modules.Notifications/Application/FileNotifications.cs`
- Modifier : `api/src/PartyPlan.Modules.Notifications/NotificationsModule.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/FileNotificationsTests.cs`

**Interfaces :**
- Produit : `IFileNotifications.Enfiler(NotificationAEnvoyer)`, **`void`**, sans
  `SaveChangesAsync`. Consommé par les tâches 3, 5, 7.
- Produit : `NotificationAEnvoyer(Guid? UserId, Guid EventId, string Category,
  string Title, string Body, string? DeepLink, DateTimeOffset ScheduledFor,
  string DedupKey)`.

- [ ] **Étape 1 : Écrire les tests**

Trois comportements : `Enfiler` puis `SaveChanges` écrit la ligne ; `Enfiler` seul
n'écrit rien ; une clé déjà présente n'ajoute pas de seconde ligne et ne lève pas.

Ce dernier point est le cœur : l'implémentation absorbe le conflit, parce qu'un rappel
déjà planifié est le cas **normal** d'un balayage rejoué, pas une erreur.

- [ ] **Étape 2 : Lancer, vérifier l'échec.**

- [ ] **Étape 3 : Écrire le contrat**

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>Notification à envoyer, telle qu'un module la décrit.</summary>
public sealed record NotificationAEnvoyer(
    Guid? UserId,
    Guid EventId,
    string Category,
    string Title,
    string Body,
    string? DeepLink,
    DateTimeOffset ScheduledFor,
    string DedupKey);

/// <summary>
/// Mise en file d'une notification. Contrat public du module Notifications.
/// <para>
/// <b>Inscrit sans sauvegarder</b>, comme <see cref="IJournalActivite"/> : la ligne est
/// validée par le <c>SaveChangesAsync</c> de l'appelant, donc dans la transaction de
/// l'action. Une réponse à une invitation qui échoue ne doit pas laisser partir une
/// notification annonçant une réponse qui n'a pas eu lieu.
/// </para>
/// </summary>
public interface IFileNotifications
{
    void Enfiler(NotificationAEnvoyer notification);
}
```

- [ ] **Étape 4 : Écrire l'implémentation.** `FileNotifications` injecte
  `INotificationsDbContext`, `IClock` et `IIdGenerator`. Elle tient un ensemble des clés
  déjà enfilées dans la portée courante : deux appels identiques dans la même requête
  échoueraient sinon à la sauvegarde, avant même d'atteindre la contrainte.

- [ ] **Étape 5 : Enregistrer** dans `NotificationsModule.AddServices`, en `AddScoped`.

- [ ] **Étape 6 : Lancer, vérifier le vert**, `make frontieres`, commit.

---

## Tâche 3 : `EF-NOT-01` et `EF-NOT-02`

Les deux déclencheurs événementiels.

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Events/Application/AttendanceService.cs`
  (`DeclarerAsync`) — `EF-NOT-01`
- Modifier : `api/src/PartyPlan.Modules.Events/Application/EventService.cs`
  (là où `dateChange`/`lieuChange` sont déjà calculés au lot 1.10) — `EF-NOT-02`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsEvenementiellesTests.cs`

**Interfaces :**
- Consomme : `IFileNotifications` (tâche 2), `IEventMembership`.

- [ ] **Étape 1 : Écrire les tests**

`EF-NOT-01` : quand Camille répond, **le propriétaire** reçoit une notification
`invitation.answer`, et Camille n'en reçoit pas — on ne se notifie pas soi-même.

`EF-NOT-02` : quand la date change, **tous les membres sauf l'auteur** reçoivent
`event.changed`. Le payload du fil du lot 1.10 dit déjà quels champs ont bougé ; la
notification le reprend dans son corps.

Plus : une réponse rejouée à l'identique n'enfile pas deux notifications, la clé de
déduplication portant l'identifiant du membre et son nouveau statut.

- [ ] **Étape 2 : Lancer, vérifier l'échec.**

- [ ] **Étape 3 : Implémenter.** Injecter `IFileNotifications`, appeler `Enfiler` **avant**
  le `SaveChangesAsync` existant, à côté de `journal.Consigner`. Les deux contrats
  partagent la même transaction et la même raison de l'exiger.

- [ ] **Étape 4 : Lancer le vert, puis la suite d'intégration complète.**

- [ ] **Étape 5 : Commit.**

---

## Tâche 4 : `IEvenementsAVenir`, `IPlanificateurRappels` et l'ordonnanceur

L'ordonnanceur planifie mais **n'envoie pas encore** : c'est ce découpage qui rend
l'idempotence vérifiable avant qu'un seul message ne parte.

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IEvenementsAVenir.cs`
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IPlanificateurRappels.cs`
- Créer : `api/src/PartyPlan.Modules.Events/Application/EvenementsAVenir.cs`
- Créer : `api/src/PartyPlan.Infrastructure/Notifications/OrdonnanceurNotifications.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/OrdonnanceurTests.cs`

**Interfaces :**
- Produit : `IEvenementsAVenir.ListerAsync(DateTimeOffset borneMax, CancellationToken)`
  → `IReadOnlyList<EvenementAVenir>` avec
  `EvenementAVenir(Guid EventId, Guid OwnerUserId, DateTimeOffset StartsAt, DateTimeOffset? EndsAt)`.
- Produit : `IPlanificateurRappels.PlanifierAsync(EvenementAVenir, DateTimeOffset maintenant, CancellationToken)`.
- Produit : `OrdonnanceurNotifications`, `BackgroundService`.

- [ ] **Étape 1 : Écrire les tests**

**Le test qui compte** : trois passes consécutives sur le même jeu de données produisent
exactement le même nombre de notifications.

Plus : un événement hors fenêtre n'est pas planifié ; une exception dans un planificateur
n'empêche pas les autres de tourner ; l'ordonnanceur lit `IClock`, donc une horloge fixée
à J-3 produit le rappel J-3.

- [ ] **Étape 2 : Lancer, vérifier l'échec.**

- [ ] **Étape 3 : Écrire `IEvenementsAVenir` et son implémentation.**

L'implémentation emploie `IgnoreQueryFilters()` — **seul endroit du lot** — parce que le
périmètre d'événements n'est pas amorcé hors requête HTTP et que la liste renverrait
sinon zéro ligne. Le commentaire doit le dire, et dire aussi pourquoi c'est acceptable :
la vue rendue ne porte ni nom, ni adresse, ni membre, donc aucun contenu d'événement.

Borne : les événements dont le début est dans les `borneMax` à venir, plus ceux terminés
depuis moins de deux jours — `EF-NOT-06` notifie le lendemain.

- [ ] **Étape 4 : Écrire l'ordonnanceur**

```csharp
protected override async Task ExecuteAsync(CancellationToken jeton)
{
    while (!jeton.IsCancellationRequested)
    {
        await PasseAsync(jeton).ConfigureAwait(false);
        await Task.Delay(Cadence, jeton).ConfigureAwait(false);
    }
}
```

`Cadence` = une minute. La passe crée sa propre portée d'injection, liste les événements,
puis pour chacun :

```csharp
// Le périmètre est ouvert événement par événement : le garde de cloisonnement reste
// actif, borné à ce seul événement. Le contourner par IgnoreQueryFilters ferait de
// l'ordonnanceur le seul code du projet à lire toutes les soirées à la fois.
using var acces = scope.AllowTemporarily(evenement.EventId);

foreach (var planificateur in planificateurs)
{
    try
    {
        await planificateur.PlanifierAsync(evenement, maintenant, jeton);
    }
    catch (Exception erreur) when (erreur is not OperationCanceledException)
    {
        // Journalisée et non propagée : la planification est idempotente, la passe
        // suivante réessaiera, et un planificateur en panne ne doit pas priver les
        // trois autres de leur tour.
        logger.LogError(erreur, "...");
    }
}
```

- [ ] **Étape 5 : Enregistrer** le `BackgroundService`, avec un drapeau de configuration
  permettant de l'éteindre — les tests d'intégration ne doivent pas voir une passe se
  déclencher sous leurs pieds.

- [ ] **Étape 6 : Lancer le vert, `make frontieres`, commit.**

---

## Tâche 5 : les quatre planificateurs de rappels

Une sous-tâche par planificateur, chacune close par son test et son commit.

**Fichiers :** un fichier par planificateur, dans le module propriétaire.
**Test :** un fichier de test par planificateur.

- [ ] **5a — `RappelsDeReponse` (Events, `EF-NOT-03`)**

À J-3 et J-1, aux membres au statut `Unknown`. Clé : `{eventId}:invitation.pending:{userId}:j-3`
puis `:j-1`. Test : un membre qui a répondu ne reçoit rien ; le rappel J-1 n'annule pas
celui de J-3 déjà envoyé.

- [ ] **5b — `RappelsDeDebut` (Events, `EF-NOT-05`)**

2 h avant, aux membres comptés présents. Clé occurrence `debut`. Test : un absent ne
reçoit rien ; un événement dans 3 h n'est pas encore planifié.

- [ ] **5c — `RappelsDArticles` (Shopping, `EF-NOT-04`)**

À J-1, **au propriétaire seul**, s'il reste au moins un article sans attributaire. Clé
occurrence `j-1`. Test : une liste entièrement attribuée ne produit rien ; une liste vide
non plus — il n'y a rien à signaler.

- [ ] **5d — `RappelsDeDette` (Settlements, `EF-NOT-06`)**

Le lendemain de la fin, à chaque débiteur, avec **son** montant. Le solde vient de
`ISettlementStatus` et du calcul déjà en place. Clé occurrence `lendemain`. Test : un
membre à solde nul ne reçoit rien ; un créancier non plus ; le montant annoncé est celui
du solde, au centime.

Ce dernier touche au domaine financier : le jeu de référence du `§6.5` doit rester vert.

---

## Tâche 6 : la passe d'envoi

**Fichiers :**
- Créer : `api/src/PartyPlan.Modules.Notifications/Application/EnvoiNotifications.cs`
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IEnvoiNotifications.cs`
- Modifier : l'ordonnanceur, pour appeler la passe d'envoi après la planification
- Test : `api/tests/PartyPlan.IntegrationTests/EnvoiNotificationsTests.cs`

**Interfaces :**
- Consomme : `IPushSender`, `IPushDeviceRegistry`, `users.timezone` via un contrat de
  lecture à ajouter au module Users s'il n'existe pas.
- Produit : `IEnvoiNotifications.EnvoyerLesDuesAsync(DateTimeOffset, CancellationToken)`
  → nombre envoyé.

- [ ] **Étape 1 : Écrire les tests**

Préférence désactivée : rien n'est envoyé, **et `SentAt` est tout de même horodaté** —
sinon la ligne est réexaminée à chaque réveil, indéfiniment.

Événement en sourdine : idem.

Plage de silence : un destinataire à `Europe/Paris` à 23 h locale n'est pas servi ; le
même à 9 h l'est ; un rappel `event.starting_soon` traverse la plage.

Deux fuseaux : `Pacific/Auckland` et `Europe/Paris` ne sont pas en heure creuse au même
instant, et le test le vérifie explicitement — c'est tout l'objet de « heure locale du
destinataire ».

Échec d'envoi : `SentAt` est horodaté malgré tout.

Sans clé : la boucle tourne, journalise, horodate (`NF-DEV-04`).

- [ ] **Étape 2 : Lancer, vérifier l'échec.**

- [ ] **Étape 3 : Implémenter.** `TimeZoneInfo.FindSystemTimeZoneById` sur le fuseau du
  profil ; un fuseau introuvable retombe sur `Europe/Paris` plutôt que d'écarter la
  personne — ne jamais notifier vaut moins bien que notifier à une heure approchante.

- [ ] **Étape 4 : Brancher la passe dans l'ordonnanceur, après la planification.**

- [ ] **Étape 5 : Lancer la suite complète, commit.**

---

## Tâche 7 : `EF-NOT-10` et le regroupement

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Shopping/Application/ShoppingService.cs`
  (`AttribuerAsync`)
- Modifier : `api/src/PartyPlan.Modules.Messages/Application/MessageService.cs`
  (envoi d'un message)
- Modifier : `FileNotifications` — le plafond de `RG-NOT-02`
- Test : `api/tests/PartyPlan.IntegrationTests/RegroupementActiviteTests.cs`

- [ ] **Étape 1 : Écrire les tests**

Deux articles pris à une minute d'intervalle → **une** notification. À vingt minutes
d'intervalle → deux. Un message puis un article dans le même quart d'heure → une seule.
Celui qui agit ne se notifie pas lui-même.

- [ ] **Étape 2 : Lancer, vérifier l'échec.**

- [ ] **Étape 3 : Implémenter le plafond dans `FileNotifications`.** C'est le seul endroit
  du lot qui regarde le passé avant d'écrire — assumé, parce que `RG-NOT-02` parle d'une
  fenêtre glissante et non d'une clé. Le commentaire doit le dire.

- [ ] **Étape 4 : Lancer le vert, commit.**

---

## Tâche 8 : endpoints de liste, de lecture, de préférences et de sourdine

**Fichiers :**
- Créer : `api/src/PartyPlan.Modules.Notifications/Application/NotificationService.cs`
- Créer : `api/src/PartyPlan.Modules.Notifications/Endpoints/NotificationEndpoints.cs`
- Modifier : `NotificationsModule`
- Modifier : `docs/api/openapi.json`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsLectureTests.cs`

**Interfaces :**
- Produit : `NotificationPage(IReadOnlyList<NotificationView> Items, bool HasMore, int UnreadCount)`.

- [ ] **Étape 1 : Écrire les tests**

Cloisonnement d'abord : chacun ne voit que les siennes, un `PlatformAdmin` non plus
(`RG-ADM-01`). Puis le curseur, comme au lot 1.10. Puis marquer lu, marquer tout lu, les
préférences, la sourdine.

- [ ] **Étape 2 à 5** : rouge, service, endpoints (`before`/`limit`, plafond vérifié avant
  lecture, convention identique à la discussion et au fil), vert, OpenAPI régénéré, commit.

---

## Tâche 9 : écran des notifications

**Fichiers :**
- Créer : `app/lib/core/models/notification.dart`
- Créer : `app/lib/core/network/notifications_api.dart`
- Créer : `app/lib/features/notifications/notifications_page.dart`
- Modifier : `app/lib/core/providers.dart`, `app/lib/app/router.dart`,
  `app/lib/features/evenement/coquille_evenement.dart` (entrée et pastille)
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/notifications_test.dart`

- [ ] **Étape 1 : Test du modèle et de l'écran.** États chargement (squelettes), vide,
  erreur. Une non-lue est distinguée ; le tap ouvre le lien profond et marque lu.

- [ ] **Étape 2 à 6** : rouge, modèle, client, provider, écran, pastille, vert, commit.

L'écran réutilise le vocabulaire visuel du fil d'activité là où il s'applique — mais
c'est une liste sur laquelle **on agit** (on ouvre, on marque lu) : elle emploie donc des
`PpCard`, contrairement au fil. La distinction posée au lot 1.10 doit rester lisible.

---

## Tâche 10 : écran des préférences

**Fichiers :**
- Créer : `app/lib/features/profil/preferences_notifications_page.dart`
- Modifier : la section sourdine dans `parametres_evenement_page.dart`
- Modifier : ARB, routeur, entrée depuis les paramètres du compte
- Test : `app/test/features/preferences_notifications_test.dart`

- [ ] Sept interrupteurs, un par catégorie, chacun nommé en clair côté utilisateur — pas
  `invitation.answer` mais « Réponses aux invitations ». Écriture optimiste avec retour
  arrière visible (`RG-UI-03`, `PpOptimisticAction` existe).
- [ ] La sourdine vit dans les paramètres de l'événement : c'est là qu'on la cherche.

---

## Tâche 11 : exploitation

- [ ] Consigner dans `docs/exploitation.md` que l'ordonnanceur impose l'instance unique,
      au même titre que le hub SignalR, et **pourquoi** : le `dedup_key` protège la
      planification, pas l'envoi. Deux instances enverraient tout en double.
- [ ] Documenter le drapeau d'extinction de l'ordonnanceur et son usage.
- [ ] Vérifier que `.env.example` déclare toute clé nouvelle (`NF-OPS-09`).

---

## Tâche 12 : vérification et clôture

- [ ] **`make verif`** — tout vert, sortie sous les yeux avant toute annonce.
- [ ] **Recette locale sans clé FCM** : créer une soirée à J-3, avancer l'horloge par
      configuration, constater les notifications en console. Consigner la procédure.
- [ ] **`python3 tools/recette/parcours-evenement.py`** — 84 vérifications toujours vertes.
- [ ] **Feuille de route** : cocher le lot 1.11, en distinguant ce qui est vérifié en
      local de ce qui attend un vrai appareil et une vraie clé.
- [ ] **Revue** — `superpowers:requesting-code-review`. Ne pas fusionner dans `main` ni
      pousser sans accord explicite.

---

## Ce que ce plan ne fait pas

- **`EF-NOT-09`, repli par courriel** — `P1`, hors feuille de route du lot 1.11.
- **Aucun réessai d'envoi** : un jeton mort est mis au rebut, ce qui suffit.
- **Aucune notification par message** : `EF-NOT-10` regroupe, `RG-MSG-01` écarte de
  concurrencer une messagerie.
- **Aucune file externe, aucun Redis.**
