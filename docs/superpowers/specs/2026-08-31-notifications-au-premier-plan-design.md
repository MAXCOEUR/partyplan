# Notifications au premier plan, consentement sur l'accueil, bouton Google officiel

*31/08/2026*

Trois chantiers décidés le 31/08/2026, réunis parce qu'ils touchent le même parcours :
être prévenu, et pouvoir le devenir.

## 1. Le problème

Une notification qui arrive pendant que l'application est ouverte n'existe pas. Android
ne l'affiche pas — c'est le comportement documenté de FCM, qui remet le message à
l'application au lieu de le poser dans le volet — et `ServiceNotificationsFirebase`
n'écoute que `onMessageOpenedApp` et `getInitialMessage`, c'est-à-dire les deux chemins
du *tap*. Aucun code ne lit `FirebaseMessaging.onMessage`. Résultat : une dépense ajoutée
pendant qu'on regarde la discussion ne produit rien, nulle part.

Deux conséquences pratiques :

- pendant une soirée, quand tout le monde a l'application ouverte, c'est exactement le
  moment où les notifications comptent le plus, et c'est le seul moment où elles ne
  s'affichent pas ;
- rien ne distingue « aucune notification » de « notification perdue », ni pour
  l'utilisateur ni pour la recette.

Deux problèmes voisins traités ici :

- le consentement n'est proposé que sur le tableau de bord d'une soirée. Quelqu'un qui
  n'ouvre jamais ce tableau de bord ne voit jamais la proposition, et n'a aucune
  notification sans savoir pourquoi ;
- sur Android, l'entrée « Continuer avec Google » est un `OutlinedButton` de l'application.
  Sur le Web, c'est le bouton officiel rendu par le SDK. Les deux parcours ne se
  ressemblent pas, et celui d'Android ne porte aucun des repères visuels que les gens
  reconnaissent.

## 2. Ce qui est décidé

### 2.1 Bandeau interne, pas notification système

Au premier plan, la notification passe par un bandeau dessiné par l'application, glissant
depuis le haut, tapable, effaçable, disparaissant seul. Pas de `flutter_local_notifications`.

Pourquoi : l'application est déjà sous les yeux. Poser une notification dans le volet du
téléphone pendant qu'on regarde l'écran concerné duplique l'information au lieu de
l'apporter. Le bandeau évite en outre une dépendance, un canal Android à déclarer, et
fonctionne tel quel sur le Web, où l'application est aussi livrée.

Ce que cela coûte : la notification reçue au premier plan ne reste pas dans l'historique
du téléphone. Elle reste dans l'écran Notifications de l'application, qui est sa vraie
mémoire.

### 2.2 La règle de suppression : par écran **et** par soirée

Le bandeau est masqué uniquement quand l'écran ouvert montre déjà ce que la notification
annonce, **pour la même soirée**.

| Écran ouvert | Catégories masquées |
|---|---|
| Discussion | `discussion.message`, `discussion.mention`, `poll.new` |
| Dépenses | `expense.new` |
| Courses | `shopping.unclaimed` |
| Sondages | `poll.new` |
| Activité | `activity` |
| Notifications | toutes |

`poll.new` figure deux fois, et ce n'est pas une erreur : un sondage créé paraît dans le
fil de discussion autant que dans l'écran des sondages (`MessageService` implémente
`IPollAnnouncement`). Il est déjà visible dans les deux cas.

Trois clauses fermes :

1. **Une notification d'une autre soirée s'affiche toujours.** Être dans la discussion de
   la crémaillère ne doit rien masquer du week-end à la montagne.
2. **Les catégories sans écran d'accueil s'affichent toujours** : `balance.due`,
   `invitation.answer`, `invitation.pending`, `event.changed`, `event.starting_soon`.
   Aucun écran ne les rend redondantes.
3. **En cas de doute, on affiche.** Une catégorie inconnue de la table — celle qu'on
   ajoutera dans six mois — s'affiche. Le défaut d'une table de suppression doit être de
   ne rien supprimer, sinon toute catégorie nouvelle naît muette et personne ne le voit.

### 2.3 Le consentement revient sur l'accueil

Une carte en tête de l'accueil, visible tant que la question n'est pas tranchée,
c'est-à-dire tant que l'état vaut `aDemander`. Elle réapparaît à chaque lancement. Le
bouton ouvre la boîte système ; la carte disparaît dès que la question est tranchée, dans
un sens ou dans l'autre.

La carte du tableau de bord d'une soirée est conservée : les deux portent le même geste.

**`RG-NOT-03` est amendée**, pas contournée. Sa forme précédente — « demandé au moment où
il devient utile, jamais au premier lancement » — visait la boîte système d'Android, qui ne
se présente qu'une fois : refusée par réflexe, elle ne se redemande jamais et l'utilisateur
est perdu pour de bon. Cette crainte reste fondée, et la nouvelle rédaction la garde :

> **RG-NOT-03** — La boîte de dialogue système n'est jamais ouverte d'autorité au
> lancement. Elle ne s'ouvre qu'après un geste explicite. L'invitation à faire ce geste,
> elle, est proposée dans l'application aussi longtemps que la question n'est pas
> tranchée : sur l'accueil et sur le tableau de bord d'une soirée.

La distinction est le fond du sujet : ce qui est irréversible, c'est la boîte système. Une
carte dans l'application est réversible, donc elle peut insister.

### 2.4 Le bouton Google, identique sur les trois plateformes

Le bouton d'Android adopte la forme officielle de Google : surface blanche, contour
`#747775`, logo « G » quadrichrome, `Roboto Medium` 14, libellé « Continuer avec Google ».
C'est le bouton que le SDK rend déjà sur le Web ; Android et, plus tard, iOS s'alignent
dessus.

Le logo est dessiné par un `CustomPainter` à partir des tracés officiels, plutôt
qu'importé en image ou via une dépendance SVG : quatre chemins de Bézier, aucun binaire au
dépôt, aucune dépendance de plus, et un rendu net à toute densité d'écran.

Le sens de l'alignement compte : c'est Android qui rejoint le Web, pas l'inverse. La forme
du bouton Web est imposée par le SDK Google et ne se retouche pas.

## 3. Architecture

### 3.1 Ce que la notification doit porter

Le message FCM ne transporte aujourd'hui ni la catégorie ni l'identifiant de la soirée.
Sans eux, aucune règle de suppression n'est possible : `data` contient `deepLink` et
`groupe`, et le lien profond ne dit pas de quelle catégorie il relève.

`PushMessage` gagne donc deux champs, et `FirebasePushSender` deux entrées dans `data` :

```
data: { deepLink, groupe, categorie, evenement }
```

`categorie` est une constante de `NotificationCategories`, déjà stable en base puisque les
préférences s'y adossent. `evenement` est l'identifiant de la soirée, ou absent pour une
notification qui n'en relève pas.

`EnvoiNotifications` les remplit depuis la notification qu'il tient déjà : aucune lecture
supplémentaire, aucune frontière de module franchie.

### 3.2 Côté application : trois pièces séparées

**`NotificationRecue`** — ce qu'une notification poussée devient une fois lue : titre,
corps, catégorie, identifiant de soirée, destination. Construite depuis
`RemoteMessage.data` et validée comme une entrée extérieure, au même titre que le lien
profond l'est déjà par `LienNotification`.

**`RegleAffichagePremierPlan`** — fonction pure : *cette notification, reçue alors que tel
écran est ouvert, doit-elle s'afficher ?* Elle ne connaît ni Flutter, ni Firebase, ni
Riverpod. C'est la pièce qui porte la valeur métier de ce lot, donc celle qui doit être
testable sans monter une application.

Elle prend l'écran courant sous la forme d'un `ZoneVisible` : le chemin du routeur et,
quand on est dans une soirée, l'onglet ouvert. Le chemin donne déjà la soirée et les
écrans poussés (`/events/:id/sondages`, `/notifications`) ; seuls les onglets de la
coquille n'y figurent pas, l'`IndexedStack` ne changeant pas d'adresse. La coquille publie
donc son onglet dans un provider, et le remet à zéro en se démontant.

**`PpBandeauNotification`** — le widget. Posé une seule fois, dans le `builder` de
`MaterialApp.router`, au-dessus de l'écran courant. Il ne sait rien des catégories : on lui
donne une notification à montrer, il la montre.

### 3.3 Le flux

```
FCM ──onMessage──▶ ServiceNotifications.ecouterPremierPlan
                        │
                        ▼
                 NotificationRecue.depuis(data)
                        │
                        ▼
        RegleAffichagePremierPlan.doitAfficher(recue, zoneVisible)
                        │
             ┌──────────┴──────────┐
           non                    oui
             │                     │
          ignorée          bandeauProvider = recue
                                   │
                                   ▼
                        PpBandeauNotification
                                   │
                              tap ─┴─▶ routeur.go(destination)
```

Rien n'est mis en file : une notification chasse la précédente. Empiler des bandeaux
au-dessus d'un écran qu'on est en train de lire reproduirait exactement le bruit que la
règle de suppression cherche à éviter.

### 3.4 Erreurs

Le premier plan suit la règle déjà tenue par le reste du service : rien de ce qui touche
aux notifications ne fait échouer autre chose. Une `data` incomplète, une catégorie
inconnue, un lien profond invalide — chacun a un comportement défini (afficher sans
destination, afficher quand même, ignorer le lien) et aucun ne lève.

## 4. Tests

| Pièce | Test |
|---|---|
| `PushMessage` → `data` | La catégorie et la soirée partent ; une notification hors soirée n'envoie pas `evenement` |
| `EnvoiNotifications` | Les deux champs viennent bien de la notification enregistrée |
| `NotificationRecue` | Construction depuis une `data` complète, partielle, vide, hostile |
| `RegleAffichagePremierPlan` | Un cas par ligne du tableau, plus les trois clauses fermes : autre soirée, catégorie sans écran, catégorie inconnue |
| `PpBandeauNotification` | S'affiche, se tape, ouvre la destination, s'efface |
| Carte de consentement | Présente sur l'accueil quand `aDemander`, absente sinon |
| `PpBoutonGoogle` | Rendu sur Android, libellé et logo présents ; le Web garde le bouton du SDK |

La règle de suppression est couverte cas par cas : c'est une table, et une table se teste
ligne à ligne, sinon la ligne oubliée est précisément celle qui se trompera.

## 5. Hors périmètre

- L'empilement des notifications d'activité sur l'appareil (`RG-NOT-02`, toujours en
  attente au lot 1.11) : il concerne l'arrière-plan, pas le premier plan.
- iOS : le bouton Google y prendra la même forme, l'application n'y est pas encore livrée.
- Le repli par courriel (`EF-NOT-09`, `P1`).
