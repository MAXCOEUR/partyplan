# Écrans événementiels et socle hors ligne — conception

> Sous-projet **B1** du plan d'achèvement de la V1.0.
> Date : 20/08/2026. Statut : validé, prêt pour le plan d'implémentation.

## 1. Objectif

Rendre utilisable ce que l'API sait déjà faire. Les lots 1.2, 1.3 et 1.4 sont livrés
côté serveur — seize endpoints, cinquante-trois vérifications de recette — mais aucun
écran Flutter ne les appelle. À la fin de B1, le parcours « créer une soirée → inviter →
répondre » fonctionne de bout en bout, depuis l'application comme depuis un navigateur
sans session.

Le hors ligne (`NF-OFFLINE-01`) est traité ici plutôt qu'en fin de V1.0, sur arbitrage
explicite. Il est donc conçu générique dès le départ : les modules suivants s'y branchent
sans le réécrire.

## 2. Périmètre

### Dans B1

| Lot | Ce qui reste |
|---|---|
| 1.1 | `EF-AUTH-11` conversion d'une participation d'invité en compte, et son test de non-doublon |
| 1.2 | `EF-EVT-04` tableau de bord, `RG-UI-02`, écrans accueil / création / tableau de bord / paramètres |
| 1.3 | `EF-INV-02` QR code exportable, `RG-INV-05` parcours en deux écrans, écrans d'aperçu et d'adhésion, recette à trois interactions |
| 1.4 | Écran des invités |
| 1.12 | Navigation `RG-UI-01`, `NF-OFFLINE-01`, `NF-A11Y-03` sur les écrans produits |

### Hors B1, et pourquoi

| Exigence | Renvoyée à | Motif |
|---|---|---|
| `RG-EVT-02` — règlements en attente avant suppression | B2 | Exige un contrat public exposé par le module `Settlements`, qui n'existe pas. La confirmation renforcée reste la seule barrière, comme la feuille de route le consigne déjà. |
| `EF-PRES-07` — relance des membres sans réponse | B4 | Exige les notifications. |
| `NF-PERF-04` — premier affichage utile sous 2,5 s en 4G | B6 | C'est une mesure, pas un écran. Elle risque d'imposer un changement de moteur de rendu : le bundle web pèse 31 Mo en CanvasKit. |
| Écrans de démarrage et de découverte (lot 1.12) | B6 | Ils présentent le produit fini ; les écrire avant que les modules existent reviendrait à les réécrire. |

### Satisfaction partielle assumée

`RG-UI-02` exige que le tableau de bord affiche « avant l'événement, les articles non
attribués ; après, le montant que l'utilisateur doit ». Ces deux informations viennent
des modules `Shopping` et `Settlements`, donc de B2. B1 livre la structure et les
sections déjà nourries ; **`RG-UI-02` ne sera pleinement satisfaite qu'à la fin de B2**.
La tâche correspondante de la feuille de route reste donc décochée à l'issue de B1, et
c'est voulu : la cocher serait un faux.

## 3. Socle hors ligne

### 3.1 Point d'insertion

`ApiClient` (`app/lib/core/network/api_client.dart`, 171 lignes) est déjà le point de
sortie réseau unique : jeton, corrélation, idempotence et traduction des erreurs y sont
traités une fois pour toutes, précisément parce que « dispersés dans les écrans, ces
traitements finiraient par différer d'un appel à l'autre ». Le hors ligne relève du même
raisonnement et se place au même endroit.

Trois collaborateurs nouveaux, chacun testable seul :

| Unité | Rôle | Dépend de |
|---|---|---|
| `CacheLecture` | Conserve la dernière réponse de chaque `GET` | Magasin clé-valeur |
| `FileEcritures` | Conserve les écritures non parties, les rejoue dans l'ordre | Magasin clé-valeur |
| `EtatReseau` | Expose « en ligne », « hors ligne », « rejeu en cours », et la date du dernier succès | Les deux précédents |

`ApiClient` les orchestre ; les écrans ne connaissent que `EtatReseau`.

### 3.2 Cache de lecture

Chaque `GET` réussi est écrit sous une clé `GET|chemin|paramètres triés`, avec la charge
utile JSON et l'horodatage de réception. Les paramètres sont triés pour que deux requêtes
équivalentes ne produisent pas deux entrées.

En échec réseau, le `GET` sert l'entrée du cache si elle existe et `EtatReseau` porte la
date de fraîcheur. L'écran affiche alors un bandeau « données du 20/08 à 14 h 32 ». Sans
cette date visible, l'utilisateur ne peut pas distinguer un état ancien d'un état courant,
et prendra une décision sur des chiffres périmés.

Le cache est **vidé à la déconnexion et au changement de compte**. Il contient le contenu
d'événements privés : le laisser en place après une déconnexion violerait la promesse
d'événement privé sur un appareil partagé.

### 3.3 File d'écritures

Une écriture qui échoue pour cause de réseau est inscrite dans une file persistante :
méthode, chemin, corps, clé d'idempotence, horodatage, et un compteur de tentatives.

**La clé d'idempotence est générée à l'inscription en file, pas à l'émission.** C'est le
point qui fait tenir tout le mécanisme : régénérer la clé au rejeu produirait une clé
neuve, l'idempotence du serveur ne reconnaîtrait rien, et un rejeu créerait un doublon.

La file est **ordonnée et rejouée séquentiellement**. Une écriture ne part que si toutes
celles qui la précèdent sont sorties de la file. Rejouer en parallèle ferait par exemple
partir un changement de statut avant l'adhésion qui le rend possible.

**La mise en file est un choix explicite par opération, jamais un comportement par
défaut.** Voir §3.5.

### 3.4 Détection de l'absence de réseau

Par l'échec réel de la requête (`DioException` de type connexion ou délai dépassé), et
non par une bibliothèque de connectivité. Un wifi capté sans accès à Internet — une salle
des fêtes, une cave, un réseau captif d'hôtel — est le cas le plus fréquent pour ce
produit, et `connectivity_plus` le déclare « connecté ». Une dépendance de moins, et une
détection qui correspond à ce qui se passe vraiment.

Le rejeu est déclenché par le premier appel réseau qui réussit, et par une reprise
manuelle depuis le bandeau.

### 3.5 Politique de rejeu

| Réponse au rejeu | Décision | Motif |
|---|---|---|
| 2xx | Retirée de la file | |
| 4xx métier | Retirée de la file, signalée à l'utilisateur | Une écriture définitivement refusée qui resterait en file la bloquerait pour toujours |
| 401 après rafraîchissement échoué | Conservée, rejeu suspendu | La session est à rouvrir ; l'écriture n'est pas fautive |
| 5xx | Conservée | Panne serveur, pas erreur d'écriture |
| Échec réseau | Conservée | |

Une écriture retirée sur 4xx est présentée par `PpOptimisticAction`, qui existe déjà et
implémente `RG-UI-03` — écriture optimiste avec retour arrière visible et explicite.

### 3.6 Conséquences côté API

Le module `Events` déclare `.RequireIdempotency()` sur un seul endpoint,
`POST /v1/events`. Deux autres écritures peuvent entrer dans la file et doivent donc être
protégées :

- `POST /v1/join/{token}` — adhésion ;
- `POST /v1/events/{eventId}/members/{memberId}/transfer-ownership`.

Le mécanisme existe (`IdempotencyRequirement`, `IdempotencyMiddleware`) : une ligne par
endpoint, plus un test d'intégration par endpoint vérifiant qu'un second appel à clé
identique rejoue la réponse sans second effet.

Les `PATCH` et `DELETE` du module sont idempotents par nature — rejouer un changement de
statut ou une exclusion produit le même état. Rien à faire.

**`POST /v1/events/{eventId}/invitation/rotate` ne doit jamais entrer dans la file.**
Il est délibérément non idempotent : chaque appel produit un jeton neuf, et c'est tout
son intérêt (`EF-INV-05` — régénérer le lien ferme une porte restée ouverte). Rejoué, il
régénérerait une seconde fois et invaliderait le lien que l'utilisateur vient de
partager. La mise en file est donc déclarée opération par opération.

### 3.7 Magasin retenu

`shared_preferences`. Seule option disponible à l'identique sur Android, iOS et Web sans
étape de compilation native — et le Web est une cible de publication, pas un accessoire.
Les charges utiles se comptent en kilo-octets : une liste d'événements, une liste de
membres.

**Limite consignée** : ce magasin ne conviendra plus au fil d'activité paginé du lot 1.10
ni à un historique de dépenses volumineux. Le jour venu, `CacheLecture` et `FileEcritures`
étant deux unités isolées derrière une interface, changer de magasin ne touchera ni
`ApiClient` ni un seul écran. Sur-dimensionner aujourd'hui coûterait une dépendance et
une compilation native pour un besoin qui n'existe pas encore.

### 3.8 Ce que le socle ne fait pas

- **Aucune résolution de conflit.** Le serveur reste la source de vérité ; le dernier
  écrit gagne. Une synchronisation à trois voies serait un projet en soi, sans valeur
  métier démontrée ici.
- **Aucun calcul hors ligne.** En particulier aucun calcul de solde ni de répartition :
  le domaine financier n'a qu'une source de vérité (`§6.2`), et en écrire une seconde
  côté client répéterait la faute que le lot 0.2b a explicitement refusé de commettre en
  écrivant un second calcul dans le jeu de démonstration.
- **Aucune mise en file des lectures.** Un `GET` sans réseau et sans cache échoue et
  affiche l'état d'erreur existant.

## 4. Couche données

Patron existant, sans invention. `ComptesApi` (307 lignes) sert de modèle.

```
app/lib/core/models/evenement.dart      Evenement, ResumeEvenement, RolesMembre
app/lib/core/models/membre.dart         Membre, StatutPresence
app/lib/core/models/invitation.dart     Invitation, ApercuInvitation
app/lib/core/network/evenements_api.dart
```

Providers Riverpod ajoutés à `core/providers.dart`, suivant les existants.

Le client Dart reste **écrit à la main**. C'est la décision du lot 0.5 : le générateur
produit un paquet séparé et une chaîne de compilation supplémentaire, disproportionnés
tant que la surface reste sous quelques dizaines d'endpoints. Seize endpoints de plus ne
franchissent pas ce seuil.

### Endpoints consommés

| Verbe | Chemin | Écran |
|---|---|---|
| GET | `/v1/events` | Accueil |
| POST | `/v1/events` | Création |
| GET | `/v1/events/{id}` | Tableau de bord |
| PATCH | `/v1/events/{id}` | Paramètres |
| DELETE | `/v1/events/{id}` | Paramètres |
| GET | `/v1/events/{id}/invitation` | Invitation |
| POST | `/v1/events/{id}/invitation/rotate` | Invitation |
| PATCH | `/v1/events/{id}/join-enabled` | Invitation |
| GET | `/v1/join/{token}` | Aperçu |
| GET | `/v1/join/code/{shortCode}` | Saisie du code |
| POST | `/v1/join/{token}` | Adhésion |
| GET | `/v1/events/{id}/members` | Invités |
| PATCH | `/v1/events/{id}/members/me` | Invités, tableau de bord |
| DELETE | `/v1/events/{id}/members/me` | Paramètres — quitter |
| DELETE | `/v1/events/{id}/members/{memberId}` | Invités — exclure |
| POST | `/v1/events/{id}/members/{memberId}/transfer-ownership` | Paramètres |

Un endpoint reste à créer : la conversion d'invité, §5.9.

## 5. Écrans

Registre convivial, pas applicatif d'entreprise (`§10.3`). Charte fixée dans
`docs/brand/charte.md` ; le système de design du lot 0.6 fournit déjà cartes, étiquettes,
avatars, pile d'avatars, pastilles de statut, barres de progression, états vide, erreur et
chargement, plus `PpMoney` et `PpClaimChip`. Aucun composant nouveau n'est prévu hors de
ceux listés ci-dessous.

### 5.1 Accueil — `EF-EVT-05`

Liste « à venir » puis « passés », séparées par un intitulé de section. `CarteEvenement`
existe déjà dans `accueil_page.dart`, écrite « pour la liste dès que l'API la fournit » :
elle est reprise et complétée d'une pile d'avatars et d'une pastille de statut personnel.

États : chargement, vide (déjà écrit et conservé), erreur, hors ligne avec date de
fraîcheur.

### 5.2 Création — `EF-EVT-01`, `EF-EVT-02`

Assistant en trois étapes avec barre de progression.

1. Nom
2. Date, heure de début, date et heure de fin facultatives, lieu
3. Description

Deux corrections apportées au patron d'assistant, sans lesquelles il serait plus pénible
qu'un formulaire :

- **Navigation libre.** Retour en arrière sans perte de saisie, et appui direct sur un
  segment de la barre de progression pour y aller.
- **« Créer » actif dès l'étape 2.** Nom et date suffisent à l'API ; les étapes suivantes
  sont facultatives, et tout est modifiable ensuite par `EF-EVT-03`.

L'étape 2 rappelle la règle `EF-EVT-02` sous le champ de fin : sans fin saisie, l'API pose
une fin implicite à +12 heures. La règle est invisible sinon.

Idempotence : la clé est générée à l'ouverture de l'assistant, pas à l'appui sur
« Créer ». Un double appui ne crée donc jamais deux événements, ce que
`POST /v1/events` exige déjà.

### 5.3 Tableau de bord — `EF-EVT-04`, `RG-UI-02`

Une page composée de **sections autonomes**, chacune un widget indépendant qui décide
seul de s'afficher ou non. B2 et B4 ajoutent leur section sans toucher à la page.

Sections livrées par B1 :

| Section | Source | Condition d'affichage |
|---|---|---|
| Identité — nom, date, lieu | `EventSummary` | toujours |
| Compte à rebours | date de début | événement à venir |
| Ma présence | `EventMember` de l'appelant | statut `Unknown` en premier, `RG-PRES-01` |
| Synthèse des présences | `presentCount`, `maybeCount`, `memberCount` | toujours |
| Partager l'invitation | `joinEnabled` | rôle `Owner` ou `Admin`, et adhésions ouvertes |
| Sans réponse | membres au statut `Unknown` | rôle `Owner` ou `Admin`, et au moins un |

Emplacements réservés, vides en B1 : articles non attribués, ce que je dois, prochaine
étape du planning, fil d'activité.

`RG-PRES-04` gouverne l'affichage de la synthèse : présents et têtes sont deux décomptes
distincts, et les confondre fausserait toutes les quantités de courses. La section les
présente séparément dès B1, avant même que les courses existent, pour que l'habitude soit
prise.

### 5.4 Invités — `EF-PRES-01` à `EF-PRES-06`

Liste des membres : avatar, nom affiché, pastille de statut, horaires d'arrivée et de
départ, accompagnants, rôle. Synthèse en tête, « n présents sur m invités », les
« peut-être » comptés à part (`RG-PRES-03`).

Chacun ne modifie que son propre statut (`EF-PRES-03`). Un `Owner` ou un `Admin` dispose
en plus de l'exclusion (`RG-ROLE-03` : la ligne est horodatée, jamais supprimée, les
données financières subsistent).

Accompagnants plafonnés à dix, avec le motif affiché en clair : au-delà, il s'agit d'un
autre événement.

### 5.5 Paramètres de l'événement

Modifier (`EF-EVT-03`), quitter (`EF-EVT-06`), transférer la propriété, supprimer
(`EF-EVT-07`).

Le transfert est présenté **avant** « quitter » pour un propriétaire : `RG-ROLE-02` lui
interdit de partir sans transférer, et découvrir l'interdiction après avoir appuyé sur
« quitter » est un cul-de-sac. La cible doit posséder un compte — un invité sans compte ne
retrouverait pas l'événement depuis un autre appareil — et la liste de sélection ne
propose donc que les membres rattachés à un compte, avec l'explication affichée.

Suppression : confirmation renforcée par saisie du nom de l'événement.

### 5.6 Invitation — `EF-INV-02`, `EF-INV-05`, `EF-INV-06`

Lien complet, code court `PLAN-XXXXXX`, QR code, bouton de partage natif, régénération,
fermeture des arrivées.

Le QR est dessiné par `qr_flutter`, déjà présent au dépôt pour l'enrôlement du second
facteur, et déjà assorti du raisonnement qui vaut ici : aucun appel réseau, et fond blanc
imposé que le thème sombre ne fournit pas, sans lequel le code n'est pas lisible par un
téléphone.

**`EF-INV-02` — export en image.** Contrainte de plateforme à consigner : sur le Web, un
téléchargement déclenché par la page est bloqué dans le contexte d'exécution des
artefacts, et sur mobile l'enregistrement en galerie demanderait une permission et une
dépendance de plus. Le partage natif (`share_plus`) couvre le besoin réel — envoyer le QR
dans une conversation — sur les trois plateformes. C'est ce qui sera implémenté, et la
tâche sera cochée à ce titre.

La régénération est précédée d'un avertissement : le code court est renouvelé avec le
lien, et tout lien déjà partagé cesse de fonctionner.

### 5.7 Aperçu d'invitation — `RG-INV-04`

Accessible sans session, sur `/join/:token` et via la saisie du code court.

Affiche le nom, la date, le lieu et le nombre de participants. **Ni liste nominative, ni
dépenses, ni jeton.** La restriction est déjà vérifiée par un test d'intégration côté
API ; l'écran ne demande pas davantage.

Si les adhésions sont fermées (`EF-INV-06`), l'aperçu reste lisible et explique le refus,
plutôt que de renvoyer une erreur opaque.

La saisie du code court reste tolérante — minuscules, espaces, tirets, absence de préfixe
— comme l'API l'accepte déjà.

### 5.8 Adhésion sans compte — `EF-INV-04`, `RG-INV-05`

**Deux écrans, jamais trois** : saisie du prénom, puis choix du statut.

Le critère d'acceptation est chiffré : depuis un navigateur sans session, de l'ouverture
du lien à l'affichage du tableau de bord, **trois interactions au maximum et aucune saisie
d'adresse e-mail**. Le décompte prévu : appui sur « Participer » depuis l'aperçu, saisie
du prénom et validation, choix du statut. La recette le vérifie.

Aucune dépendance à `user_id` n'est introduite — règle non négociable n° 7. Le jeton
d'invité remis est restreint à l'événement, et son empreinte est déjà conservée à
l'adhésion (`RG-AUTH-07`, fait au lot 1.1).

### 5.9 Conversion d'un invité en compte — `EF-AUTH-11`

Seule partie de B1 qui demande du code serveur nouveau.

**Côté API** : `POST /v1/auth/register` et `POST /v1/auth/login` acceptent un champ
facultatif `guestToken` **dans le corps de la requête**, et non dans l'en-tête
`Authorization`. Ces deux endpoints sont anonymes ; y faire transiter un jeton d'invité
par l'en-tête reviendrait à faire dépendre un parcours anonyme de l'intergiciel
d'authentification, qui rejette de toute façon ce jeton pour cause d'audience distincte.
Un champ explicite se lit, se teste et se documente dans l'OpenAPI.

Le service rattache au compte tout `event_member` dont le `GuestSessionHash` correspond à
l'empreinte du jeton présenté, en positionnant `UserId` sur la ligne existante — **sans
jamais créer de seconde ligne**.

La liaison se fait sur l'empreinte du jeton, **jamais sur le prénom** (`RG-AUTH-07`) :
deux homonymes ne doivent pas fusionner.

Trois cas limites, traités explicitement :

| Cas | Règle |
|---|---|
| Le membre invité est déjà rattaché à un autre compte | Il n'est pas repris. Le jeton présenté ne donne aucun droit sur un membre déjà nominatif. |
| Le compte est déjà membre du même événement à un autre titre | La ligne d'invité est horodatée comme retirée (`RemovedAt`), la ligne existante est conservée. |
| Le jeton d'invité ne correspond à aucun membre | L'inscription réussit normalement, sans rattachement, et sans message d'erreur : un jeton périmé ne doit pas empêcher de créer un compte. |

**Report explicite vers B2.** Le deuxième cas laisse les contributions financières de la
ligne retirée rattachées à cette ligne. Tant que dépenses et attributions n'existent pas,
c'est sans conséquence. Dès que le module `Expenses` existe, la fusion devra réaffecter
ces contributions à la ligne conservée, faute de quoi le critère d'acceptation
`EF-AUTH-11` — « la dépense reste rattachée à lui » — serait faux. **Cette réaffectation
est une tâche de B2, à inscrire dans son plan.** Ne pas la consigner ici reviendrait à
laisser un défaut silencieux derrière une case cochée.

**Côté application** : proposition de création de compte depuis le tableau de bord d'un
invité, avec l'argument affiché — retrouver l'événement depuis un autre appareil.

Critère d'acceptation du cahier des charges, à vérifier tel quel : *un invité ayant
rejoint un événement, saisi une dépense et pris deux articles, puis créé un compte,
retrouve l'événement dans sa liste ; la dépense reste rattachée à lui ; aucun doublon de
membre n'apparaît*. Les dépenses et articles n'existant qu'en B2, la recette de B1
vérifie la partie « événement retrouvé, aucun doublon », et B2 complétera.

### 5.10 Navigation — `RG-UI-01`

`coquille_evenement.dart` porte déjà les cinq entrées. B1 branche l'onglet Accueil sur le
tableau de bord et place Invités, Invitation et Paramètres sous « Plus ». Courses,
Dépenses et Planning conservent leur état vide jusqu'à B2 et B4.

La contrainte reste celle qui est déjà écrite dans le fichier : cinq entrées, jamais
plus, « car c'est en ajoutant un sixième onglet *juste pour cette fois* que la navigation
se dégrade ».

## 6. Dépendances ajoutées

Deux, pas davantage. Le projet tient à ce que rien ne dépende d'un compte externe pour
être développé (règle non négociable n° 5), et les deux respectent cette contrainte.

| Paquet | Pour quoi | Justification |
|---|---|---|
| `shared_preferences` | Magasin du cache de lecture et de la file d'écritures | §3.7. Seule option identique sur Android, iOS et Web sans étape de compilation native |
| `share_plus` | Partage du lien d'invitation et du QR code | §5.6. Feuille de partage native ; aucun service tiers, aucune clé |

Aucune dépendance de connectivité (§3.4). Aucune dépendance de génération de QR :
`qr_flutter` est déjà au dépôt pour l'enrôlement du second facteur.

## 7. Accessibilité

`NF-A11Y-03` — libellés sémantiques sur toute action, y compris une phrase lisible pour
les décomptes de présence. `NF-A11Y-02` — cibles tactiles de 44 points. Les deux sont déjà
vérifiés par test automatisé au lot 0.6 ; les tests sont étendus aux écrans nouveaux
plutôt que réécrits.

## 8. Tests

Développement piloté par les tests, sans exception. Ordre : test rouge, implémentation,
test vert.

| Cible | Nature | Points vérifiés |
|---|---|---|
| `CacheLecture` | unitaire Dart | Clé stable quel que soit l'ordre des paramètres ; service depuis le cache en échec réseau ; date de fraîcheur exacte ; purge à la déconnexion |
| `FileEcritures` | unitaire Dart | Rejeu ordonné ; clé d'idempotence **identique** entre l'inscription et le rejeu ; 4xx qui retire ; 5xx et échec réseau qui conservent ; refus d'inscrire une opération non éligible |
| `EtatReseau` | unitaire Dart | Transitions en ligne / hors ligne / rejeu |
| `EvenementsApi` | unitaire Dart | Analyse des réponses, traduction des erreurs RFC 9457 |
| Chaque écran | widget `flutter_test` | États chargement, vide, erreur, hors ligne ; règles de rôle ; libellés sémantiques |
| Assistant de création | widget | Retour sans perte ; « Créer » actif dès l'étape 2 ; clé d'idempotence unique par assistant |
| Adhésion | widget | Deux écrans, trois interactions |
| Idempotence des deux endpoints | intégration xUnit | Second appel à clé identique : réponse rejouée, aucun second effet |
| Conversion d'invité | intégration xUnit | Aucun doublon de membre ; liaison par empreinte et non par prénom ; deux homonymes ne fusionnent pas |
| Parcours complet | `tools/recette/parcours-evenement.py` | Extension aux écrans et à la conversion |

Les tests montent `PartyPlanApp` et non un `MaterialApp` nu — correction déjà apportée au
lot 0.6, faute de quoi ils ne voient pas la même application que la production.

## 9. Ce qui a été écarté

| Option | Motif du rejet |
|---|---|
| Cache et file écran par écran | Code répété dans chaque module et une file par module — exactement ce que le placement du hors ligne en B1 vise à éviter |
| Base locale miroir (Drift, Isar) | Seconde source de vérité à l'échelle du produit. Le lot 0.2b a déjà refusé ce raisonnement à plus petite échelle, en n'écrivant pas de second calcul de répartition dans le jeu de démonstration |
| `connectivity_plus` | Déclare « connecté » un wifi sans Internet, c'est-à-dire le cas le plus fréquent pour ce produit |
| Formulaire de création d'une page | Arbitré en faveur de l'assistant. Réserve levée par la navigation libre et « Créer » dès l'étape 2 |
| Génération du client Dart depuis l'OpenAPI | Décision du lot 0.5 maintenue : seize endpoints de plus ne franchissent pas le seuil qui justifierait un paquet séparé |
| Enregistrement du QR en galerie | Permission et dépendance supplémentaires pour un besoin que le partage natif couvre sur les trois plateformes |

## 10. Risques

| Risque | Portée | Traitement |
|---|---|---|
| Le magasin `shared_preferences` sature sur un historique volumineux | Lot 1.10 | Interface isolée : changer de magasin ne touchera ni `ApiClient` ni un écran |
| Une écriture en file dont l'endpoint n'est pas idempotent | Correction silencieuse de données | Éligibilité déclarée par opération, refus d'inscrire par défaut, test unitaire dédié |
| `RG-UI-02` non satisfaite à l'issue de B1 | Feuille de route | Tâche laissée décochée et motif consigné |
| Bundle web de 31 Mo | `NF-PERF-04` | Hors périmètre, mesuré en B6, susceptible d'imposer un changement de moteur de rendu |

## 11. Références

`docs/cahier-des-charges.md` — `EF-EVT-01` à `07`, `EF-INV-01` à `06`, `EF-PRES-01` à
`06`, `EF-AUTH-11`, `RG-ROLE-01` à `03`, `RG-INV-04`, `RG-INV-05`, `RG-PRES-01` à `04`,
`RG-AUTH-07`, `RG-UI-01` à `03`, `NF-OFFLINE-01`, `NF-A11Y-02`, `NF-A11Y-03`, `§6.2`,
`§10.3`.

`docs/roadmap.md` — lots 1.1, 1.2, 1.3, 1.4, 1.12.

`docs/adr/` — `ADR 0002` monolithe modulaire, `ADR 0003` domaines.
