# Notifications immédiates et réglage par soirée — conception

**But** : qu'un message, un sondage, une dépense ou un achat prévienne les autres tout
de suite, et que chacun règle ce qu'il veut recevoir **soirée par soirée**.

**Décidé le 30/08/2026.** L'inscription reste transactionnelle ; l'envoi cesse
d'attendre l'horloge quand un humain vient d'agir. Le réglage par soirée surcharge le
réglage global, catégorie par catégorie. Le regroupement quitte le serveur pour
l'appareil.

Suite du **lot 1.11**, dont le transport et l'ordonnanceur sont livrés. Prend appui sur
`2026-08-26-notifications-declencheurs-design.md`, et **revient sur deux de ses
décisions** — voir §1.

---

## 1. Ce sur quoi ce lot revient, et pourquoi

Le cahier des charges du 26/08 écartait la notification de discussion nominale :

> Un message produit une notification `activity` regroupée, pas une par message.
> `RG-MSG-01` écarte explicitement de concurrencer une messagerie.

Deux constats l'ont invalidé.

**Le premier est factuel** : ce repli n'a jamais été écrit. `MessageService` ne
référence pas `IFileNotifications`. Ni un message, ni une mention, ni un sondage, ni une
dépense ne produit quoi que ce soit. Trois modules sont muets, pas un. Le lot se relisait
comme fait parce que la table, les index et les catégories existaient — le piège que le
cahier des charges précédent décrivait lui-même au §1, et dans lequel il est tombé.

**Le second est un usage** : sur une soirée réelle, la discussion est le fil où tout se
décide. Une notification par quart d'heure y arrive après la conversation. Ne pas
concurrencer une messagerie signifie ne pas construire de messagerie — pas priver d'avis
la fonction la plus utilisée.

`RG-MSG-01` reste : un seul fil, pas de salons, pas d'accusés de lecture, pas de
présence. Ce lot ne touche qu'à la notification.

## 2. Deux chemins de livraison, un seul expéditeur

| Chemin | Déclencheur | Délai |
|---|---|---|
| **Immédiat** | un humain a agi : message, sondage, dépense, achat | la seconde qui suit |
| **Planifié** | J-7, J-3, J-1, H-2, lendemain | le tour d'horloge |

Le geste métier continue d'**inscrire** la notification dans sa propre transaction. Une
dépense dont l'enregistrement échoue ne fait partir aucun avis annonçant une dépense qui
n'existe pas — la garantie du lot précédent, qu'on ne brade pas pour gagner une seconde.

Après validation, le service métier **réveille** l'expéditeur. Le réveil est un signal en
mémoire, ce que l'instance unique déjà imposée par l'ordonnanceur (`docs/exploitation.md`
§1.2) rend légitime.

**Le réveil ne déclenche que la passe d'envoi.** L'ordonnanceur en a deux — planifier,
puis envoyer. Réveiller la planification à chaque message recalculerait les rappels de
toutes les soirées pour un seul envoi.

**Écarté — l'envoi en ligne dans la requête.** Appeler Firebase dans le fil de la requête
ajoute leur latence à celle de l'envoi du message, et une panne de leur côté ralentit une
action qui n'a rien à voir. Il aurait fallu du parallélisme et des reprises : un second
expéditeur à côté de celui qui existe.

**Écarté — la cadence resserrée.** Passer l'ordonnanceur à deux secondes est une ligne à
changer, mais c'est de l'interrogation de base en continu pour rien la plupart du temps,
et « direct » y devient « presque ».

## 3. Le réglage par soirée

Une table `event_notification_preferences` — utilisateur, événement, catégorie, activé —
qui ne contient **que les écarts**. Une soirée réglée comme d'habitude n'y a aucune
ligne.

Résolution, dans l'ordre :

1. sourdine de la soirée (`event_mute_settings`) → rien ne part ;
2. écart de la soirée pour cette catégorie ;
3. préférence globale pour cette catégorie ;
4. valeur d'usine.

**La sourdine reste une notion distincte**, et n'est pas remplacée par « toutes les
catégories à non ». Une catégorie ajoutée plus tard doit rester muette sur une soirée
mise en sourdine ; une liste de « non » figée au moment du réglage la laisserait passer.

**Onze catégories** au lieu de sept :

| Catégorie | Chemin | Nouveau |
|---|---|---|
| `invitation.answer` | planifié | |
| `event.changed` | planifié | |
| `invitation.pending` | planifié | |
| `shopping.unclaimed` | planifié | |
| `event.starting_soon` | planifié | |
| `balance.due` | planifié | |
| `activity` | immédiat | |
| `discussion.message` | immédiat | ✅ |
| `discussion.mention` | immédiat | ✅ |
| `poll.new` | immédiat | ✅ |
| `expense.new` | immédiat | ✅ |

La discussion en **deux catégories** plutôt qu'un réglage à trois positions : les trois
états demandés — tout, seulement les `@`, rien — tombent alors des deux cases oui/non que
`EF-NOT-07` sait déjà stocker et afficher. Aucune valeur à trois états à inventer en
base, à sérialiser et à migrer le jour où il en faudrait une quatrième.

## 4. Les déclencheurs à écrire

| Quand | Catégorie | Destinataires |
|---|---|---|
| Message citant | `discussion.mention` | les personnes citées |
| Message simple | `discussion.message` | les autres membres |
| Sondage créé | `poll.new` | tous les membres |
| Dépense créée | `expense.new` | les porteurs d'une part |
| Article acheté | `activity` | les autres membres |

Jamais l'auteur du geste, jamais un membre sans compte — la contrainte que
`ShoppingService` applique déjà et qui sert de précédent.

**La dépense ne prévient que ceux qu'elle engage.** Être averti d'une dépense dont on ne
porte aucune part est du bruit, et le bruit fait couper la catégorie entière.

**Une personne citée reçoit sa mention même si `discussion.message` est coupé.** C'est le
sens du découpage en deux catégories : couper le bavardage ne coupe pas le fait d'être
appelé.

L'achat d'un article rejoint la prise en charge sous `activity`, qui existe déjà. Deux
catégories pour deux gestes de la même liste se régleraient toujours ensemble.

## 5. Trois règles du cahier des charges changent

**`RG-NOT-01` — la plage de silence est retirée, pas restreinte.** *Décidé le
30/08/2026, en cours de lot ; la première version de ce document la restreignait au
chemin planifié.*

Le serveur n'applique plus aucune plage horaire. Deux motifs. Le premier : tout téléphone
offre un mode « ne pas déranger », mieux fait, déjà réglé par la personne, et qui vaut
pour toutes ses applications — le dupliquer côté serveur, c'est décider à sa place.
Le second : la règle retardait à 8 h du matin des notifications de soirée qui ne servent
plus à rien à cette heure-là.

Le drapeau « immédiat » des catégories survit : il ne sert plus à contourner un silence,
mais à décider si l'envoi est réveillé après validation ou attend le tour d'horloge.

**`RG-NOT-02` — le regroupement par quart d'heure disparaît**, remplacé par une clé de
groupe par soirée sur l'appareil. Android empile les notifications d'une même clé sous un
seul bandeau : vingt messages font une entrée dépliable, pas vingt lignes. Le serveur
cesse de calculer une fenêtre.

*Conséquence à connaître* : sur le Web, la notion équivalente **remplace** au lieu
d'empiler. Le navigateur montrera la dernière notification de la soirée, pas la pile.
Accepté ; le Web n'est pas la cible principale des notifications.

*Conséquence technique* : grouper suppose que l'application construise la notification
elle-même, donc un message Firebase de données plutôt qu'un message de notification.
`EF-NOT-10` et sa clé de déduplication restent — ils protègent la planification, pas
l'affichage.

**`EF-NOT-03` gagne J-7**, en plus de J-3 et J-1.

## 6. Écrans

**Paramètres d'une soirée** : la liste des catégories. La discussion s'y présente en
trois choix — tout, seulement les `@`, rien — qui écrivent les deux cases sous-jacentes.
Un bouton « comme mes réglages habituels » efface les écarts de cette soirée.

**Écran global des préférences** : inchangé. Il gagne seulement les quatre nouvelles
catégories, l'écran étant déjà construit sur la liste des catégories.

## 7. Endpoints

| Verbe | Route | Rôle |
|---|---|---|
| `GET` | `/v1/events/{eventId}/notifications/preferences` | écarts de la soirée, résolus |
| `PATCH` | `/v1/events/{eventId}/notifications/preferences` | poser ou retirer un écart |

La lecture renvoie la valeur **résolue** par catégorie, plus l'indication qu'il s'agit
d'un écart ou de l'héritage. Sans quoi l'écran devrait refaire la résolution, et deux
implémentations d'une même règle finissent toujours par diverger.

Le retrait d'un écart est une valeur nulle, pas une route de suppression : l'écran a
trois états à écrire pour la discussion, dont l'un est « comme d'habitude ».

## 8. Tests

- l'auteur d'un geste n'est jamais notifié ;
- un membre sans compte n'est jamais notifié ;
- une personne citée reçoit sa mention alors que `discussion.message` est coupé ;
- un écart de soirée l'emporte sur la préférence globale ;
- la sourdine l'emporte sur un écart qui autorise ;
- une transaction en échec ne laisse aucune notification ;
- le réveil ne déclenche pas la passe de planification ;
- une notification immédiate part à 23 h ; un rappel planifié à 23 h est reporté à 8 h ;
- une dépense ne notifie que les porteurs d'une part.

Les deux derniers valent d'être écrits en premier : ce sont les changements de règle, et
un test qui les fige empêche un retour en arrière involontaire.

## 9. Ce que ce lot ne fait pas

- **Aucun repli par courriel** (`EF-NOT-09`), toujours hors périmètre.
- **Aucun réessai d'envoi.** Un jeton mort est mis au rebut, ce qui suffit.
- **Aucune file externe.** Le `CLAUDE.md` les écarte, et le réveil en mémoire suffit à
  l'instance unique.
- **Aucun accusé de lecture, aucune présence** : `RG-MSG-01` tient.
- **Aucune notification de modification ou de suppression** d'un message, d'une dépense
  ou d'un sondage. Seule la création prévient.

## 10. Ordre d'implémentation

1. Les quatre catégories, leur drapeau « immédiat », et l'amendement du cahier des
   charges pour `RG-NOT-01`, `RG-NOT-02` et `EF-NOT-03`.
2. Migration `event_notification_preferences`, et la résolution en quatre étapes du §3,
   testée seule.
3. Le réveil de l'expéditeur, avec la garantie qu'il ne planifie pas.
4. Les déclencheurs, un module à la fois : Messages, puis Polls, puis Expenses, puis
   l'achat dans Shopping.
5. Les deux endpoints.
6. La clé de groupe et le passage au message de données.
7. J-7.
8. L'écran des paramètres de soirée.
9. Vérification en local sans clé Firebase (règle 5), puis feuille de route.

L'étape 2 avant l'étape 4 : un déclencheur qui part sans que la résolution soit juste
notifie les mauvaises personnes, et c'est le genre de défaut qu'on ne voit qu'en
production.
