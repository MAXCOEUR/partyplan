# Modèle de domaine

## Tables

```
users
sessions
password_reset_tokens
email_verification_tokens
admin_audit_entries

events
event_members
shopping_items
expenses
expense_participants
expense_revisions
settlements
tasks
polls / poll_options / poll_votes
messages
event_schedule_items
notifications
notification_preferences
event_mute_settings
push_devices
idempotency_keys
```

Il n'existe pas de table `event_invitations` : le jeton du lien et le code court sont
portés par la ligne `events` elle-même. Il n'existe pas non plus de `shopping_lists` :
un événement a une seule liste, matérialisée par les articles qui le référencent.
Ajouter ces tables serait une indirection sans usage.

## Énumérations

`User.PlatformRole`  : `User` · `Support` · `PlatformAdmin` — portée : l'instance
`EventMember.Status` : `Unknown` · `Going` · `Maybe` · `NotGoing` · `Late` · `EarlyLeave`
`EventMember.Role`   : `Owner` · `Admin` · `Member` — portée : un seul événement

Les deux axes de rôle sont indépendants. Être `PlatformAdmin` ne confère aucun droit
dans un événement dont on n'est pas membre.

## Règle d'accès — non négociable

Toute requête portant sur une ressource d'événement remonte la chaîne
`User → EventMember → Event`. Aucun endpoint ne renvoie un événement au seul motif
que l'identifiant existe. Un filtre global est appliqué au niveau du DbContext,
et non laissé à la discrétion de chaque requête.

**Le rôle plateforme ne contourne pas ce filtre.** Un `PlatformAdmin` non membre d'un
événement reçoit 404 sur toutes ses ressources, comme n'importe quel tiers
(`RG-ADM-01`). L'administration agit sur des comptes, jamais sur des contenus.

## Journal d'audit

`admin_audit_entries` est en ajout seul : le rôle applicatif ne dispose ni de `UPDATE`
ni de `DELETE`. L'adresse de l'auteur y est recopiée à l'écriture, afin que la trace
reste lisible après suppression de son compte.

## Invités sans compte

Un `event_member` peut exister sans `user_id` : un `DisplayName` et un jeton de session
signé suffisent pour participer. La liaison à un compte créé ultérieurement se fait
en conservant le même `event_member`, afin de ne pas perdre les dépenses ni les
attributions d'articles.

## Remboursements

L'algorithme minimise le nombre de transactions (débiteurs/créditeurs triés,
appariement glouton). Il ne persiste pas de solde : il recalcule à la demande
depuis `expenses` + `expense_participants`, et `settlements` n'enregistre que les
remboursements déclarés comme effectués.
