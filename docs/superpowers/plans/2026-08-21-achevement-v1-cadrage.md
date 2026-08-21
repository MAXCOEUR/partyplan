# Achèvement V1.0 — cadrage et découpage

**Objectif** : une application utilisable de bout en bout pour une soirée réelle, plus
le site vitrine.

**Date** : 21/08/2026. **Branche de départ** : `feat/b1-ecrans-evenementiels`.

## Hors périmètre, sur décision explicite

- Notifications (lot 1.11) — ni courriel, ni push, ni préférences.
- Connexion Google et Apple (reste désactivable, `EF-AUTH-08` déjà en place).
- Envoi de courriel réel. Mailpit reste le seul destinataire en développement.

Ces trois points ne bloquent aucun autre lot : la vérification d'adresse et la
réinitialisation de mot de passe fonctionnent déjà contre Mailpit.

## État constaté le 21/08/2026

Vérifié par inventaire des endpoints et des écrans, pas par lecture de la feuille de
route — laquelle est en retard sur le code.

| Domaine | API | Écran Flutter |
|---|---|---|
| Comptes, administration, événements, invitations, présences | 17 endpoints | fait |
| Liste de courses | 7 endpoints | **absent** |
| Dépenses | 5 endpoints | **absent** |
| Règlements | 3 endpoints | **absent** |
| Planning | **absent** | absent |
| Fil d'activité | **absent** | absent |
| Temps réel | **absent** | absent |
| Chat, sondages, tâches | **modules vides** | absent |
| Site vitrine | — | squelette dans `landing/` |

Toutes les tables existent déjà en base (`shopping_items`, `expenses`,
`expense_participants`, `expense_revisions`, `settlements`, `event_schedule_items`,
`activity_entries`, `messages`, `message_reactions`, `polls`, `poll_options`,
`poll_votes`, `tasks`). Aucune migration de schéma n'est attendue, sauf découverte
contraire au moment de l'écriture d'un module.

## Découpage en sous-projets

Chaque sous-projet produit un logiciel fonctionnel et vérifiable seul. L'ordre suit la
valeur d'usage : ce qui sert pendant la soirée avant ce qui l'accompagne.

| # | Sous-projet | Contenu | API à écrire | Plan |
|---|---|---|---|---|
| 1 | Courses | client d'API, écran de liste, ajout, attribution, achat | non | `2026-08-21-sp1-courses.md` |
| 2 | Dépenses | liste et totaux, création avec les trois assiettes, détail | non | à écrire |
| 3 | Règlements | soldes, règlements proposés, marquage, rappel sur le tableau de bord | non | à écrire |
| 4 | Planning | module `Schedule`, endpoints, écran chronologique | oui | à écrire |
| 5 | Fil d'activité | endpoints de lecture, écran, alimentation par les modules existants | oui | à écrire |
| 6 | Temps réel | hub SignalR, diffusion, abonnement Flutter | oui | à écrire |
| 7 | Chat | module `Messages`, endpoints, écran de discussion, réactions | oui | à écrire |
| 8 | Sondages et tâches | modules `Polls` et `Tasks`, endpoints, écrans | oui | à écrire |
| 9 | Navigation et finitions | coquille d'événement complète, documents légaux | non | à écrire |
| 10 | Site vitrine | pages, charte, mentions, référencement | non | à écrire |

Le plan détaillé d'un sous-projet est écrit **juste avant son exécution**, pas
d'avance : le sous-projet précédent apprend des choses sur les contrats réels, et un
plan écrit trop tôt décrit un code qui n'existera pas ainsi.

## Décisions produit arrêtées le 21/08/2026

Prises avec le propriétaire du produit, en réponse à des questions qui changeaient le
schéma de base. Reportées ici parce qu'un choix de ce genre, laissé dans une
conversation, se reperd et se redécide autrement six semaines plus tard.

### Discussion

- **Un seul fil par événement.** Pas de salons multiples : une soirée à six personnes
  se retrouverait avec des salons vides, et ce qui compte se perdrait dans celui que
  personne ne lit.
- **Les « salons » sont les dossiers d'épingles.** On épingle un message et on le range
  dans un dossier — Musique, Adresses, Photos — que l'on consulte ensuite.
- **Les dossiers d'épingles sont partagés, sans exception.** Aucune épingle privée : une
  seule notion, donc aucune question à se poser au moment d'épingler. C'est ce qui rend
  l'épingle utile — retrouver le code du portail que quelqu'un d'autre a donné.
- **Les sondages naissent dans le fil et se retrouvent dans un écran à eux.** Ils sont
  portés par un message — c'est là qu'on les crée et qu'on y répond au fil de la
  conversation — mais un sondage remonté par cinquante messages devient introuvable :
  un écran dédié les liste tous, ouverts d'abord.
- Attendus dans la discussion : réactions, réponse à un message, mention d'une
  personne, envoi d'images compressées avant l'envoi.
- **Les notifications sont préparées mais pas envoyées.** Les mentions et les messages
  produisent ce qu'il faut pour notifier plus tard ; aucun envoi n'est branché.

### Choix de la date

Le « planning » attendu n'est pas un déroulé horaire de la soirée, c'est le **choix
collectif de la date** :

- un événement peut naître **sans date** ;
- n'importe quel membre **propose** une ou plusieurs dates ;
- chacun **vote oui ou non** sur chaque date proposée ;
- **l'organisateur arrête** la date retenue, qui devient la date de l'événement.

Le déroulé horaire — les étapes de la soirée du lot 1.9 — reste hors périmètre jusqu'à
nouvel ordre : ce n'est pas ce qui manque aujourd'hui.

### Ordre d'exécution retenu

Règlements, puis choix de la date, puis discussion. Le site vitrine ferme la marche.

## Contraintes qui s'appliquent à tous les sous-projets

Reprises du cahier des charges et de `CLAUDE.md`, valeurs exactes.

- **Cloisonnement** : toute requête remonte `User → EventMember → Event`. Un endpoint ne
  renvoie jamais une ressource au seul motif que son identifiant existe.
- **`RG-ADM-01`** : un rôle plateforme non membre reçoit 404, jamais le contenu.
- **Invité sans compte** : le parcours « lien → prénom → présence » reste fonctionnel
  sans authentification. Aucune dépendance à `user_id` dans les courses, dépenses ou
  tâches — l'identité est la ligne `event_members`.
- **Montants** : `decimal` en C#, `numeric(10,2)` en base. Jamais de `double`.
- **Frontières de modules** : un module n'accède pas aux tables d'un autre. Interface
  publique uniquement, vérifiée par `make frontieres`.
- **Idempotence** : toute création porte un en-tête `Idempotency-Key`.
- **Langue** : français dans l'interface et la documentation, anglais dans le code et
  les identifiants de base. Dates affichées en JJ/MM/AAAA.
- **Tests** : xUnit côté API, `flutter_test` côté application. Test rouge avant
  implémentation, sans exception sur le domaine financier (`NF-QUAL-01`).
- **Vérification** : `flutter analyze`, `flutter test`, `dotnet test` verts avant toute
  annonce d'achèvement. Aucune affirmation sans sortie de commande.

## Développement local

`make api` et `make app` pour le rechargement à chaud. L'application web est servie sur
le port **5173**, épinglé : c'est l'origine déclarée dans
`appsettings.Development.json`. Un port libre choisi au hasard par Flutter ne figure
dans aucune origine autorisée, et le navigateur bloque alors chaque appel sans que rien
ne l'explique côté serveur.

Compte de développement : `admin@partyplan.local`. Le mot de passe amorcé est imposé au
changement dès le premier accès (`RG-ADM-10`).
