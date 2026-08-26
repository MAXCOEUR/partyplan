# Fil d'activité — conception

**But** : l'événement porte enfin sa trace de référence. Chaque action structurante
laisse une ligne horodatée, en lecture seule, opposable en cas de litige entre membres
sur les montants (`RG-FIL-02`).

**Décidé le 26/08/2026.** Le fil est alimenté par un contrat de noyau partagé, inscrit
dans la transaction de l'action métier. La phrase affichée est composée par
l'application, jamais stockée. Le lot 1.6 se ferme au passage : `activity.appended`
n'attendait que l'existence du fil.

Couvre le **lot 1.10**, plus les deux lignes de code restantes du **lot 1.6**. Le lot
1.11 fait l'objet d'une spec distincte.

---

## 1. Ce qui existe déjà, et ce qui manque

Le lot n'est pas un départ de zéro, et c'est ce qui rend son état trompeur.

**Existe** : la table `activity_entries` et son entité `ActivityEntry`, l'index
descendant `(event_id, created_at)` posé exactement pour la pagination par curseur, le
déclencheur d'ajout seul couvrant `UPDATE`, `DELETE` et `TRUNCATE` (`NF-SEC-08`), le
filtre global de cloisonnement, et les onze constantes de `ActivityKinds`.

**Manque** : huit des onze catégories ne sont **jamais écrites**. Seules
`member.joined` (`JoinService`), `member.status_changed` (`AttendanceService`) et
`event.date_or_place_changed` (`EventService`) atteignent la base. Courses, dépenses et
remboursements n'écrivent rien. Il manque aussi l'endpoint de lecture et l'écran.

Une table remplie au quart, dont les catégories sont toutes déclarées, se lit comme un
lot fait. C'est la même mécanique de retard que celle constatée le 24/08 sur les lots
1.3, 1.5, 1.7 et 1.8.

## 2. Le contrat d'écriture

`ActivityEntry` appartient au module `Events`. La règle 6 interdit à `Shopping`,
`Expenses` et `Settlements` d'écrire dans ses tables. Il faut donc une interface
publique.

`PartyPlan.SharedKernel/Contracts/IJournalActivite.cs` :

```csharp
public interface IJournalActivite
{
    void Consigner(
        Guid eventId,
        Guid? memberId,
        string actorName,
        string kind,
        object? donnees = null);
}
```

Trois options ont été pesées :

| Option | Retenue ? | Motif |
|---|---|---|
| Contrat de noyau partagé | **oui** | Motif déjà en place pour `IDiffusionEvenement`, `IPushSender`, `IAuditLog`. Six modules diffusent déjà sans connaître SignalR ; quatre journaliseront sans connaître `activity_entries`. |
| Dériver le fil de la diffusion temps réel | non | Un seul point d'appel, séduisant. Mais la diffusion part **après** la validation et ne lève jamais, par conception : une panne SignalR trouerait silencieusement la trace de référence. |
| Événements de domaine, boîte d'envoi | non | Infrastructure nouvelle pour dix points d'écriture. Le `CLAUDE.md` écarte les files de messages sans demande explicite. |

### Pourquoi la méthode ne sauvegarde pas

`Consigner` est **synchrone et ne rend pas de `Task`**. Elle inscrit l'entrée au suivi de
modifications d'EF Core ; c'est le `SaveChangesAsync` du service appelant qui la valide.

Conséquence recherchée : l'entrée et l'action métier partagent une transaction. Une
dépense enregistrée sans sa ligne de fil devient structurellement impossible, et une
action annulée ne laisse aucune trace fantôme.

C'est l'inverse exact de `IDiffusionEvenement`, qui part après validation et absorbe ses
propres pannes. Les deux contrats se ressemblent et ont des garanties opposées : la
diffusion est une optimisation, le fil est une preuve. La documentation XML de chacun
doit le dire.

Implémentation dans `PartyPlan.Infrastructure/Journal/JournalActivite.cs`, injectant
`PartyPlanDbContext` — le contexte est unique et implémente déjà les onze contrats de
module, donc l'inscription se fait naturellement dans la même unité de travail.

L'identifiant est attribué par `IIdGenerator` (uuid v7, `§7.1`) et l'horodatage par
`IClock`, comme aux trois points d'écriture existants.

### Diffusion

Après validation, `activity.appended` est diffusé avec l'entrée complète — état
résultant, pas seul identifiant (`RG-RT-02`). Cela ferme la dernière ligne de code du
lot 1.6.

La diffusion ne peut pas partir depuis `Consigner`, qui s'exécute avant le
`SaveChangesAsync` : elle annoncerait une entrée que la transaction peut encore annuler.
Elle part donc du service appelant, à l'endroit où il diffuse déjà son propre message
métier. Un ajout d'article produit ainsi deux messages, `item.created` et
`activity.appended` — c'est voulu : l'écran des courses et l'écran du fil ne lisent pas
la même chose.

## 3. Les dix catégories

`RG-FIL-01` en exige dix. Elles correspondent exactement aux constantes de
`ActivityKinds`, à une près.

| Catégorie | Module | Méthode | État |
|---|---|---|---|
| `member.joined` | Events | `JoinService` | écrit |
| `member.status_changed` | Events | `AttendanceService` | écrit |
| `event.date_or_place_changed` | Events | `EventService` | écrit, sans payload |
| `item.created` | Shopping | `AjouterAsync` | **à écrire** |
| `item.deleted` | Shopping | `SupprimerAsync` | **à écrire** |
| `item.claimed` | Shopping | `AttribuerAsync` | **à écrire** |
| `item.purchased` | Shopping | `AcheterAsync` | **à écrire** |
| `expense.created` | Expenses | `CreerAsync` | **à écrire** |
| `expense.updated` | Expenses | `ModifierAsync` | **à écrire** |
| `settlement.marked` | Settlements | `MarquerAsync` | **à écrire** |

### Une constante à retirer

`ActivityKinds.EventScheduleChanged` est morte avec le planning, abandonné le 21/08/2026
(lot 1.9). Elle n'a jamais été écrite : aucune ligne en base ne la porte, la retirer ne
réécrit donc aucune histoire et ne heurte pas la consigne « ne jamais renommer une valeur
déjà écrite ».

Même correction que celle appliquée au `§9` lors du lot 1.6, où `schedule.changed` avait
survécu à la fonctionnalité qu'il annonçait.

### Contenu des payloads

Le payload est du `jsonb`. Il porte des **données**, jamais une phrase.

| Catégorie | Payload |
|---|---|
| `member.joined` | aucun — `ActorName` suffit |
| `member.status_changed` | `{"de": "Unknown", "vers": "Yes"}` |
| `event.date_or_place_changed` | `{"champs": ["date", "lieu"]}` |
| `item.created` | `{"libelle": "Glaçons"}` |
| `item.deleted` | `{"libelle": "Glaçons"}` |
| `item.claimed` | `{"libelle": "Glaçons"}` |
| `item.purchased` | `{"libelle": "Glaçons", "montant": 4.50}` |
| `expense.created` | `{"libelle": "Courses", "montant": 62.40}` |
| `expense.updated` | `{"libelle": "Courses", "ancienMontant": 62.40, "montant": 58.10}` |
| `settlement.marked` | `{"vers": "Camille", "montant": 12.30}` |

`event.date_or_place_changed` gagne un payload qu'il n'a pas aujourd'hui, sans quoi
l'application ne peut pas distinguer un changement de date d'un changement de lieu.

**Les clés sont en français.** La convention du projet veut l'anglais dans le code et les
identifiants de base, et cette exception est assumée : la seule ligne déjà écrite en base
porte `{"de": …, "vers": …}`, et l'ajout seul interdit de la corriger. Une convention
mixte serait pire qu'une convention imparfaite mais uniforme.

**Les montants sont des nombres JSON**, comme partout ailleurs dans l'API : `decimal` en
C#, lus en `double` par l'application pour l'affichage seul. La règle 8 vise le calcul et
le stockage, tous deux inchangés — le fil n'additionne rien. Ce payload n'est jamais une
source de calcul, et le rappeler dans la documentation de l'entité évite qu'on l'y
emploie plus tard.

### Amendement proposé au cahier des charges

Trois actions d'annulation ne sont couvertes par aucune catégorie :
`ModifierAsync`/`SupprimerAsync` d'une dépense (`RG-DEP-05`, suppression logique avec
recalcul des soldes), `AnnulerAsync` d'un remboursement, `LibererAsync` d'un article.

Un fil qui consigne l'attribution mais pas la libération, le marquage d'un remboursement
mais pas son annulation, et la création d'une dépense mais pas sa disparition, est
trompeur là où il prétend être une preuve. C'est précisément le cas où deux membres se
contredisent.

`RG-FIL-01` dit « au minimum », mais la règle du dépôt est explicite : rien ne s'ajoute
à la feuille de route sans référence au cahier des charges. **Trois catégories sont donc
proposées, et non ajoutées** :

| Catégorie proposée | Module | Payload |
|---|---|---|
| `item.unclaimed` | Shopping | `{"libelle": "Glaçons"}` |
| `expense.deleted` | Expenses | `{"libelle": "Courses", "montant": 62.40}` |
| `settlement.cancelled` | Settlements | `{"vers": "Camille", "montant": 12.30}` |

Si l'amendement est retenu, `RG-FIL-01` est complété et ces trois lignes rejoignent le
tableau du chapitre 3. S'il est refusé, elles disparaissent de la spec — et le motif du
refus mérite d'être écrit, car la question se reposera au premier litige.

## 4. La lecture

```
GET /v1/events/{id}/activity?before={guid}&limit=30
```

Convention **identique à celle de la discussion** (`MessagesEndpoints`), volontairement :
deux paginations différentes dans la même application obligeraient à se souvenir laquelle
s'applique où.

Retour :

```csharp
public sealed record ActivityPage(IReadOnlyList<ActivityView> Items, bool HasMore);

public sealed record ActivityView(
    Guid Id,
    Guid? MemberId,
    string ActorName,
    string? AvatarUrl,
    string Kind,
    JsonElement? Donnees,
    DateTimeOffset CreatedAt);
```

Ordre décroissant, du plus récent au plus ancien ; `before` remonte vers le passé.
`HasMore` évite que l'application redemande indéfiniment une page qui n'existe pas.

`limit` est plafonné à 100, **vérifié avant lecture** — accepter puis rejeter une valeur
absurde ferait payer la requête. Même garde que sur les messages.

L'endpoint vit dans `EventsEndpoints.cs`, module `Events`, propriétaire de la table.

Le cloisonnement ne demande aucun code : le filtre global s'applique par le contexte
(`RG-SEC-01`, `RG-SEC-02`). Un non-membre reçoit 404, un `PlatformAdmin` non membre
aussi (règle 2, `RG-ADM-01`).

`AvatarUrl` est résolu à la lecture depuis le membre, quand il existe encore. `ActorName`
reste celui figé à l'écriture (`RG-USR-04`) : un changement de nom ne réécrit pas
l'histoire, mais la photo actuelle est la bonne pour reconnaître la personne aujourd'hui.

## 5. L'écran

**Deux surfaces.**

Un onglet « Activité » dans l'événement, sous « Plus » — la barre inférieure est déjà à
ses cinq entrées (`RG-UI-01`).

Et les **trois dernières lignes sur le tableau de bord**, suivies d'un « Tout voir ».
C'est là que le fil sert le plus : on ouvre l'événement, on voit ce qui a bougé depuis
la dernière fois.

**Chaque ligne** : avatar de l'auteur, phrase composée, horodatage relatif. La phrase est
construite par l'application depuis `kind` + payload, via les ARB (`NF-I18N-01`) :

> **Camille** a pris *Glaçons* en charge · il y a 4 min
> **Alex** a ajouté la dépense *Courses*, 62,40 € · hier

Les montants passent par `PpMoney` — chiffres tabulaires, espace insécable.

**Rien ne se clique en lecture, rien ne se supprime, aucun menu contextuel.** `RG-FIL-02`
dit lecture seule ; l'écran doit le rendre évident plutôt que l'écrire quelque part. Une
ligne renvoyant vers la ressource concernée serait utile mais suppose que la ressource
existe encore — un article supprimé n'a plus d'écran. Reporté sciemment.

**États** : squelettes au chargement (`PpSkeleton`, déjà en place), état vide avec un
motif — « Rien ne s'est encore passé ici » —, état d'erreur, et chargement de la page
suivante en bas de liste.

**Temps réel** : `activity.appended` insère la ligne en tête. Comme partout ailleurs, la
reconnexion relit l'écran entier plutôt que de rapiécer (`RG-RT-03`).

**Hors ligne** : seule la **première page** est mise en cache, via `CacheLecture` déjà en
place. Le fil est un journal en lecture seule ; hors ligne, montrer les trente dernières
lignes connues suffit, et la suite exige le réseau avec un message qui le dit.

Ce choix évite de remplacer `shared_preferences` maintenant. La limite consignée au lot
1.12 — le stockage ne tiendra pas un fil paginé complet — reste vraie mais ne se
déclenche pas : trente lignes tiennent sans peine. Le jour où le fil devra être
intégralement consultable hors ligne, les trois unités hors ligne sont isolées derrière
leur interface et le changement ne touchera ni `ApiClient` ni un écran.

## 6. Tests

TDD, test avant implémentation, sans exception (`CLAUDE.md`).

**Par catégorie, dix fois** : l'action métier écrit sa ligne, avec le bon `kind`, le bon
`ActorName` et le bon payload.

**Transaction, le test qui compte** : une action qui échoue après l'appel à `Consigner`
ne laisse **aucune** entrée. Sans ce test, le contrat pourrait être réimplémenté un jour
en `SaveChanges` immédiat, et la garantie tomberait sans que rien ne rougisse.

**Ajout seul** : `UPDATE` et `DELETE` sur `activity_entries` sont refusés par le
déclencheur, y compris pour un `PlatformAdmin` (`NF-SEC-08`, règle 4).

**Cloisonnement** : un non-membre reçoit 404 sur `GET /activity` ; un `PlatformAdmin` non
membre aussi.

**Curseur** : trois pages consécutives ne se recouvrent pas et n'omettent rien ;
`HasMore` est faux sur la dernière ; `limit` au-delà de 100 est refusé.

**Flutter** : composition de la phrase pour chacune des dix catégories, y compris payload
absent ou champ manquant — une entrée mal formée doit dégrader vers une phrase générique,
jamais faire planter l'écran. Plus les états vide, erreur et hors ligne.

### Le test à deux clients SignalR

Deux connexions au hub sur le même événement ; l'une agit, l'autre doit recevoir
`activity.appended` et le message métier correspondant.

**Ce test ne couvre pas `NF-PERF-05`.** La règle demande une propagation en moins d'une
seconde sur de vrais appareils, sur un vrai réseau ; deux clients dans le même processus
mesurent la logique de diffusion, pas la latence réelle. La mesure sur appareils reste
ouverte et **remonte au lot 1.17**, avec les autres recettes matérielles. La ligne de
recette du lot 1.6 doit être cochée en le disant, sans quoi on croira la performance
vérifiée.

De même, la recette « couper le réseau, changer trois choses, rétablir » reste
manuelle : le test automatisé vérifie que la reconnexion relit l'écran, pas qu'un
appareil réel revient exactement à jour.

## 7. Ce que ce lot ne fait pas

- **Aucun rattrapage rétroactif.** Les événements déjà en base gardent leur fil partiel.
  Reconstruire l'historique depuis les horodatages des dépenses produirait des lignes
  jamais advenues dans un journal qui prétend être une preuve. En développement,
  `make reset-db` régénère un jeu complet.
- **Aucun rapiéçage de l'état local** — reporté sciemment au lot 1.6, motif inchangé.
- **Aucun filtre, aucune recherche** dans le fil. À la première demande réelle.
- **Aucun lien depuis une ligne vers sa ressource** — voir chapitre 5.

## 8. Ordre d'implémentation

1. Contrat `IJournalActivite`, implémentation, tests de transaction et d'ajout seul.
2. Bascule des trois écritures existantes sur le contrat, à comportement identique.
3. Retrait de `EventScheduleChanged`, payload sur `event.date_or_place_changed`.
4. Les sept écritures manquantes, module par module : Shopping, Expenses, Settlements.
5. Endpoint de lecture, curseur, cloisonnement.
6. Diffusion `activity.appended` et test à deux clients — le lot 1.6 se ferme ici.
7. Écran, tableau de bord, ARB, états, hors ligne.
8. Mise à jour de `docs/roadmap.md` **au moment du commit**, pas à la fin.

L'étape 2 avant l'étape 4 : faire passer du code qui marche déjà par le nouveau contrat
éprouve le contrat sur un comportement connu, avant de lui confier sept écritures neuves.
