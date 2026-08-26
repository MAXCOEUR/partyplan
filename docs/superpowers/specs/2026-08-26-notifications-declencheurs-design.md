# Déclencheurs de notifications — conception

**But** : quelqu'un reçoit enfin quelque chose. Le transport est livré depuis le
25/08/2026 ; aujourd'hui personne n'est jamais notifié, parce qu'aucun déclencheur
n'existe.

**Décidé le 26/08/2026.** Un `BackgroundService` unique balaie la base et envoie.
Les rappels sont calculés par le module qui détient la donnée, jamais par
l'ordonnanceur. La plage de silence est appliquée à l'envoi, dans le fuseau du
destinataire. Une colonne `dedup_key` unique rend le balayage rejouable.

Couvre le **lot 1.11**. Le fil d'activité (lot 1.10) est livré et sert de précédent : le
motif de contrat de noyau partagé y a été éprouvé.

---

## 1. Ce qui existe, et le piège qu'il tend

**Existe** : `IPushSender` avec son repli console sans clé (`NF-DEV-04`), l'émetteur FCM
HTTP v1, l'enregistrement des appareils, `IPushDeviceRegistry` pour la mise au rebut, le
consentement demandé au moment utile (`RG-NOT-03`), l'ouverture du lien profond au tap.

Et surtout le **modèle de domaine complet** : `Notification` avec `ScheduledFor`,
`SentAt`, `ReadAt` et `DeepLink` ; `NotificationPreference` par catégorie ;
`EventMuteSetting` ; sept catégories déclarées ; l'index `(scheduled_for, sent_at)` posé
« pour l'ordonnanceur ».

**Le piège** : tout est là sauf ce qui déclenche. Un lot dont la table, les index et les
catégories existent se relit comme un lot fait. La feuille de route le dit déjà en
majuscules — c'est délibéré, et ça reste vrai jusqu'à ce lot.

**Manque** : les huit `EF-NOT-`, l'ordonnanceur, la plage de silence, le regroupement,
les endpoints de préférences, et deux écrans.

## 2. Deux familles de déclencheurs

| Famille | Exigences | Qui décide |
|---|---|---|
| **Événementielle** | `EF-NOT-01` réponses aux invitations, `EF-NOT-02` date ou lieu modifiés | le module, au moment où il agit |
| **Temporelle** | `EF-NOT-03` J-3 et J-1, `EF-NOT-04` articles non attribués J-1, `EF-NOT-05` début dans 2 h, `EF-NOT-06` montant dû le lendemain | le balayage |

La distinction n'est pas technique : personne ne « fait » le fait qu'on soit à J-1. Une
notification temporelle n'a pas d'auteur, et vouloir l'accrocher à une action obligerait
à inventer un déclencheur artificiel.

### La famille événementielle

Contrat de noyau partagé `IFileNotifications`, sur le motif d'`IJournalActivite` livré
au lot 1.10 :

```csharp
public interface IFileNotifications
{
    void Enfiler(NotificationAEnvoyer notification);
}

public sealed record NotificationAEnvoyer(
    Guid? UserId,
    Guid EventId,
    string Category,
    string Title,
    string Body,
    string? DeepLink,
    DateTimeOffset ScheduledFor,
    string DedupKey);
```

**Synchrone, sans sauvegarde**, exactement comme `Consigner` : la ligne est validée par
le `SaveChangesAsync` de l'appelant, donc dans la transaction de l'action. Une réponse à
une invitation qui échoue ne doit pas laisser une notification en partance annonçant une
réponse qui n'a pas eu lieu.

C'est l'inverse du choix fait pour la diffusion temps réel, et pour la même raison qu'au
lot 1.10 : le temps réel est une optimisation, une notification est un engagement envers
quelqu'un.

### La famille temporelle

**Le calcul appartient au module qui détient la donnée.** L'ordonnanceur ne sait pas ce
qu'est un article non attribué, et il ne doit pas l'apprendre : `shopping_items`
appartient à Shopping (règle 6).

D'où un contrat implémenté plusieurs fois :

```csharp
public interface IPlanificateurRappels
{
    /// <summary>Inscrit les rappels dus à cet instant. Idempotent.</summary>
    Task PlanifierAsync(DateTimeOffset maintenant, CancellationToken cancellationToken);
}
```

| Implémentation | Module | Couvre |
|---|---|---|
| `RappelsDeReponse` | Events | `EF-NOT-03` J-3 et J-1 aux membres au statut `Unknown` |
| `RappelsDeDebut` | Events | `EF-NOT-05` 2 h avant, aux membres comptés présents |
| `RappelsDArticles` | Shopping | `EF-NOT-04` J-1, à l'organisateur, s'il reste des articles sans attributaire |
| `RappelsDeDette` | Settlements | `EF-NOT-06` le lendemain, à chaque débiteur, avec son montant |

L'ordonnanceur résout toutes les implémentations enregistrées et les appelle. Ajouter un
rappel plus tard, c'est ajouter une implémentation — pas toucher à l'ordonnanceur.

Chacune a besoin de connaître les événements à venir. Events expose pour cela
`IEvenementsAVenir`, contrat public rendant identifiant, date de début, propriétaire et
fuseau — rien de plus. Ni nom, ni adresse, ni membres : un module qui planifie des
rappels n'a pas besoin du contenu de la soirée.

## 3. Le doublon est le vrai risque

Un balayage qui tourne toutes les minutes recalcule vingt fois par heure que Camille n'a
pas répondu à J-3. Sans garde, elle reçoit vingt notifications, et le produit devient
insupportable au premier essai réel.

**`notifications` n'a aujourd'hui aucune contrainte d'unicité.** Migration :

```
dedup_key  text NOT NULL
index unique sur (dedup_key)
```

Forme : `{eventId}:{categorie}:{destinataire}:{occurrence}`, où `occurrence` vaut `j-3`,
`j-1`, `debut`, `lendemain` pour les rappels temporels, et l'identifiant de l'action pour
les notifications événementielles — l'identifiant du membre qui vient de répondre, par
exemple.

**Le doublon est refusé par la base, pas par l'application.** Vérifier puis écrire
laisserait une fenêtre entre les deux, et c'est précisément la fenêtre qu'un balayage
d'une minute exploite. L'insertion en conflit est absorbée silencieusement : c'est le cas
normal d'un rappel déjà planifié, pas une erreur.

Conséquence recherchée : **le balayage est rejouable sans conséquence.** On peut le
relancer, le redémarrer, le faire tourner deux fois par accident — le résultat est le
même. C'est ce qui rend le lot testable.

## 4. La plage de silence, appliquée à l'envoi

`RG-NOT-01` interdit d'**envoyer** entre 22 h et 8 h, heure locale du destinataire.
`users.timezone` existe, vaut `Europe/Paris` par défaut et est refusé s'il est inconnu
(`EF-USR-07`) : rien à ajouter.

Deux emplacements possibles, et le choix compte :

| Où | Retenu ? | Motif |
|---|---|---|
| À l'envoi : la boucle saute les destinataires en heure creuse | **oui** | La file porte l'intention, pas un horaire négocié. Robuste à un changement de fuseau entre l'inscription et l'envoi. |
| À l'inscription : `ScheduledFor` décalé à 8 h | non | Plus lisible en base, mais devient faux si la personne change de fuseau — et le décalage serait à recalculer, ce qui suppose de savoir qu'il a été fait. |

Le prix du choix retenu : la file est relue à chaque réveil pour des notifications qui ne
partiront pas encore. L'index `(scheduled_for, sent_at)` le rend négligeable.

**`EF-NOT-05` traverse la plage** : c'est l'exception écrite dans la règle. Une soirée qui
commence à 23 h se rappelle à 21 h, et une qui commence à 1 h du matin se rappelle à 23 h.
Se taire ici rendrait le rappel inutile précisément quand il sert.

## 5. Le regroupement, et l'ajout qu'il impose

`RG-NOT-02` parle des « notifications d'activité (article pris, message) ». **Aucun
`EF-NOT-` ne les crée.** La règle décrit donc le comportement d'une notification qui
n'existe pas au cahier des charges.

Deux issues cohérentes : créer la notification, ou déclarer `RG-NOT-02` sans objet. La
seconde laisserait une règle morte, comme `schedule.changed` l'était après l'abandon du
planning.

**Retenu : la notification est créée**, catégorie `activity`, déclenchée par une
attribution d'article et par un message de discussion, adressée aux autres membres. Le
cahier des charges gagne un `EF-NOT-10` qui la décrit, plutôt que de laisser
l'implémentation devancer la spécification.

Plafonnement à l'inscription : s'il existe déjà, pour ce couple destinataire-événement,
une notification `activity` non envoyée ou envoyée depuis moins d'un quart d'heure, on
n'en ajoute pas une seconde. C'est le seul endroit du lot où l'on regarde le passé avant
d'écrire — assumé, parce que la règle parle d'une fenêtre glissante et non d'une clé.

## 6. L'ordonnanceur

Un `BackgroundService` unique, réveil **toutes les minutes**, deux passes séquentielles :

1. **Planifier** — appeler chaque `IPlanificateurRappels`. Une exception dans l'une
   n'empêche pas les autres : elle est journalisée, et la passe suivante réessaiera de
   toute façon puisque le calcul est idempotent.
2. **Envoyer** — lire les notifications dues et non parties, écarter celles dont la
   catégorie est désactivée (`EF-NOT-07`) ou l'événement en sourdine (`EF-NOT-08`),
   écarter les destinataires en heure creuse, appeler `IPushSender` pour chaque appareil
   actif, horodater `SentAt`.

**Une seule instance** (`RG-RT-04`). Deux instances enverraient tout en double : le
`dedup_key` protège la planification, pas l'envoi. À consigner dans
`docs/exploitation.md` au même titre que le hub SignalR — et c'est le second motif qui
interdit une seconde instance sans ADR préalable.

Cadence à la minute et non à la seconde : la granularité la plus fine du lot est le
rappel « 2 h avant », et personne ne remarque soixante secondes. Une cadence à la seconde
multiplierait par soixante les requêtes pour la même valeur d'usage.

`SentAt` est horodaté **même si l'envoi échoue**, et l'échec est journalisé. Sinon une
notification dont le jeton est mort serait réessayée toutes les minutes, indéfiniment.
Perdre l'avis vaut mieux que la boucle infinie — c'est déjà la doctrine d'`IPushSender`.

Sans clé FCM configurée, l'émetteur journalise en console et toute la boucle fonctionne :
la règle 5 tient, le lot est vérifiable en local, et la recette se lit dans les journaux.

## 7. Les écrans et les endpoints

```
GET    /v1/notifications                    liste, curseur
POST   /v1/notifications/{id}/read          marque lu
POST   /v1/notifications/read-all
GET    /v1/notifications/preferences
PATCH  /v1/notifications/preferences        une catégorie, poussée et courriel
PUT    /v1/events/{id}/mute                 sourdine (EF-NOT-08)
DELETE /v1/events/{id}/mute
```

Les deux premiers endpoints de préférences figurent déjà au `§8.2` ; les autres s'y
ajoutent.

**Écran « Notifications »** : liste sous « Plus », les non-lues d'abord distinguées par
un point, le tap ouvre le lien profond et marque lu. Pagination par curseur, convention
de la discussion et du fil — la troisième surface à l'employer, et toujours la même.

**Écran « Préférences de notification »**, depuis les paramètres du compte : sept
interrupteurs, un par catégorie. La sourdine par événement vit dans les paramètres de
l'événement, pas ici : c'est là qu'on la cherche.

Le compteur de non-lues alimente une pastille sur l'entrée « Plus », sur le modèle de
celle de la discussion.

## 8. Tests

TDD, sans exception.

**Idempotence, le test qui compte** : appeler la planification trois fois de suite
produit **une** notification. Sans lui, le lot semble marcher en développement et
sature les téléphones en production.

**Par rappel temporel, quatre fois** : la notification naît à la bonne date, avec le bon
destinataire, et ne naît pas pour un événement hors fenêtre. `EF-NOT-06` vérifie en plus
que le montant est celui du solde.

**Plage de silence** : un destinataire à `Pacific/Auckland` et un à `Europe/Paris` ne sont
pas en heure creuse au même instant ; le rappel de début part quand même.

**Regroupement** : deux articles pris à une minute d'intervalle produisent une seule
notification ; à vingt minutes d'intervalle, deux.

**Préférences et sourdine** : une catégorie désactivée n'envoie rien, un événement en
sourdine n'envoie rien, et la notification est tout de même horodatée pour ne pas être
réexaminée à chaque réveil.

**Transaction** : une réponse à une invitation qui échoue ne laisse aucune notification.

**Sans clé** : la boucle tourne, journalise, et `SentAt` est renseigné (`NF-DEV-04`).

**Cloisonnement** : la liste des notifications ne rend que les siennes ; un
`PlatformAdmin` ne voit pas celles des autres (`RG-ADM-01`).

**Sans réseau** (`NF-DEV-10`) : aucun test n'appelle FCM. La frontière substituée reste
`IPushSender`.

**Horloge** : l'ordonnanceur lit `IClock`, jamais `DateTimeOffset.Now`. Un rappel « J-3 »
ne se teste pas en attendant trois jours.

## 9. Ce que ce lot ne fait pas

- **`EF-NOT-09`, repli par courriel** — `P1`, absent de la feuille de route du lot 1.11.
  Le contrat `IEmailSender` existe déjà ; ce sera un ajout, pas une reprise.
- **Aucun réessai d'envoi.** Un jeton mort est mis au rebut par l'émetteur, ce qui suffit.
- **Aucune notification de discussion nominale** : un message produit une notification
  `activity` regroupée, pas une par message. `RG-MSG-01` écarte explicitement de
  concurrencer une messagerie.
- **Aucune file externe, aucun Redis** — le `CLAUDE.md` les écarte sans demande explicite,
  et une table plus un balayage suffisent à la cible du `NF-SCAL-01`.

## 10. Ordre d'implémentation

1. Migration `dedup_key`, et amendement du cahier des charges pour `EF-NOT-10`.
2. `IFileNotifications`, implémentation, tests de transaction et d'unicité.
3. `EF-NOT-01` et `EF-NOT-02` : les deux déclencheurs événementiels.
4. `IEvenementsAVenir` et `IPlanificateurRappels`, avec l'ordonnanceur qui n'envoie pas
   encore — les tests d'idempotence passent ici.
5. Les quatre planificateurs de rappels, un par tâche.
6. La passe d'envoi : préférences, sourdine, plage de silence, horodatage.
7. `EF-NOT-10` et le regroupement de `RG-NOT-02`.
8. Endpoints de liste, de lecture, de préférences et de sourdine.
9. Écran des notifications, pastille de non-lues.
10. Écran des préférences.
11. `docs/exploitation.md` : l'instance unique, et pourquoi.
12. Vérification, recette en local sans clé, feuille de route.

L'étape 4 avant l'étape 5 : un ordonnanceur qui planifie sans envoyer se teste
entièrement, et le fait de pouvoir le rejouer se vérifie avant qu'un seul message ne
parte.
