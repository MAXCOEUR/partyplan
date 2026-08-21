# PartyPlan — instructions projet

## Nature du dépôt

Monorepo. `api/` (ASP.NET Core 10), `app/` (Flutter 3.38), `landing/`, `infra/`, `docs/`.
Décisions structurantes : `docs/adr/`. Lire l'ADR concerné avant de proposer un
changement d'architecture.

## Règles non négociables

1. **Cloisonnement des événements** — toute requête remonte `User → EventMember → Event`.
   Un endpoint ne renvoie jamais une ressource au seul motif que son identifiant existe.
2. **Un rôle plateforme ne lit jamais le contenu d'un événement** (`RG-ADM-01`). Un
   `PlatformAdmin` non membre reçoit 404, comme n'importe qui. Sans cette règle, la
   promesse d'événement privé est fausse. Ne jamais ajouter de contournement « pour le
   support ».
3. **Aucun mot de passe n'est consultable** (`RG-AUTH-02`, `RG-ADM-02`). Argon2id, jamais
   de mot de passe en journal, en courriel ou dans une réponse d'API. Un administrateur
   déclenche une réinitialisation, il n'attribue pas de mot de passe.
4. **Le journal d'audit est en ajout seul** (`RG-ADM-06`). Ni `UPDATE` ni `DELETE`,
   y compris pour un `PlatformAdmin`.
5. **Tout doit tourner en local avant d'être poussé** (`§13.4`). Aucune fonctionnalité ne
   dépend d'un compte externe pour être développée : courriel capturé par Mailpit,
   notifications journalisées en console, connexions tierces désactivables. `make verif`
   avant chaque push.
6. **Frontières de modules** — un module n'accède pas aux tables d'un autre module.
   Communication par interface publique uniquement.
7. **Compte obligatoire pour rejoindre** — l'aperçu d'invitation reste public et
   restreint, mais toute nouvelle adhésion exige une session de compte valide. Le nom du
   membre vient du profil et son statut initial est `Unknown`. `event_members.user_id`
   reste nullable uniquement pour les lignes historiques et leurs références financières.
8. **Montants** — `decimal` en C#, `numeric(10,2)` en base. Jamais de `double`.
9. **Privé par défaut** — aucun événement indexable ni accessible publiquement.

## Skills à utiliser — obligatoire

Ces skills doivent être invoqués **avant** de commencer le travail correspondant, pas
après. Annoncer « Utilisation de [skill] pour [objectif] » puis suivre le skill.

| Situation | Skill | Pourquoi ici |
|---|---|---|
| « Construisons X », nouvelle fonctionnalité, nouveau lot | `superpowers:brainstorming` | Le cahier des charges fixe le quoi, pas le comment. À faire avant d'écrire une ligne. |
| Tâche multi-étapes à partir d'exigences | `superpowers:writing-plans` | Un lot de `docs/roadmap.md` compte 10 à 20 tâches : le plan écrit évite les oublis. |
| Exécution d'un plan déjà écrit | `superpowers:executing-plans` | Points de contrôle entre les étapes. |
| **Toute implémentation, tout correctif** | `superpowers:test-driven-development` | **Non négociable sur le domaine financier** : `NF-QUAL-01` exige 100 % des branches, et le jeu de référence du `§6.5` doit exister avant le calcul. |
| Bug, test rouge, comportement inattendu | `superpowers:systematic-debugging` | Avant de proposer un correctif, pas après. |
| Avant d'annoncer « c'est fini », avant un commit ou une PR | `superpowers:verification-before-completion` | Preuve d'exécution avant affirmation. Aucune annonce sans sortie de commande. |
| Fonctionnalité majeure terminée, avant fusion | `superpowers:requesting-code-review` | |
| Retour de revue reçu | `superpowers:receiving-code-review` | Vérifier techniquement plutôt qu'appliquer aveuglément. |
| Travail nécessitant l'isolation du dépôt | `superpowers:using-git-worktrees` | |
| Tâches indépendantes parallélisables | `superpowers:dispatching-parallel-agents` ou `superpowers:subagent-driven-development` | Uniquement sur demande explicite. |
| Branche terminée, tests verts | `superpowers:finishing-a-development-branch` | |
| Écrans Flutter, direction visuelle | `frontend-design:frontend-design` | Registre convivial, pas applicatif d'entreprise (`§10.3`). |
| Design system, palette, typographie, composants | `ui-ux-pro-max:ui-ux-pro-max`, `ui-ux-pro-max:design-system` | La charte est fixée dans `docs/brand/charte.md` : le skill sert à l'appliquer, pas à la redéfinir. |
| Revue du diff | `code-review` | |
| Nettoyage qualité sans chasse aux bugs | `simplify` | |
| Revue de sécurité avant publication | `security-review` | Obligatoire avant chaque jalon de publication. |
| Lancer l'application pour vérifier une modification | `run` | |
| Livrable Word / PowerPoint | voir les skills bureautiques | Instructions d'entreprise. |

### Ordre de priorité

Les skills de processus passent d'abord et fixent l'approche ; les skills
d'implémentation suivent. « Construisons X » → `brainstorming` puis
`test-driven-development` puis `frontend-design`. « Corrige ce bug » →
`systematic-debugging` puis les skills du domaine.

### Rappel

S'il y a 1 % de chance qu'un skill s'applique, il s'applique. Les justifications du type
« c'est une question simple », « je dois d'abord explorer le code » ou « le skill est
excessif ici » signalent une rationalisation, pas une exception.

## Développement local

`make up` démarre tout, `make api` et `make app` pour le rechargement à chaud,
`make reset-db` réinitialise la base et le jeu de démonstration, `make verif` avant
chaque push. Courriels sur `localhost:8025`, aucun envoi réel.

Administrateur de développement : `admin@partyplan.local` / `MotDePasseDeDeveloppement`
— refusé en production par `RG-ADM-11`.

## Conventions

- Commits conventionnels avec périmètre : `feat(shopping):`, `fix(settlements):`.
- Français dans l'interface et la documentation ; anglais dans le code et les
  identifiants de base.
- Dates affichées en JJ/MM/AAAA.
- Tests : xUnit côté API, `flutter_test` côté application. L'algorithme de
  remboursement doit être couvert par des tests avant toute modification.

## Ordre de développement

V0 socle technique → **V0.5 comptes et administration** → V1.0 événementiel.
L'identité est traitée en premier : voir `docs/roadmap.md`.

## Ce qu'il ne faut pas ajouter sans demande explicite

Redis, microservices, files de messages, GraphQL, Docker Swarm/Kubernetes,
fonctionnalités IA. Le périmètre du MVP est : comptes et administration, puis présences,
courses, dépenses, remboursements, planning, notifications.
