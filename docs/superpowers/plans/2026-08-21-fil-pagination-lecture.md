# Pagination du fil et suivi de lecture — plan

**But :** le fil de discussion ne charge plus tout l'historique, sait ce qui a été lu, et
ouvre là où la lecture s'est arrêtée.

**État avant :** `MessageService.ListerAsync` renvoie *tous* les messages de l'événement,
sans limite ni curseur. Aucune notion de lu.

## Décisions

| Point | Choix | Pourquoi |
|---|---|---|
| Curseur | `(CreatedAt, Id)`, keyset, jamais `Skip` | Un `Skip` décale dès qu'un message arrive pendant la lecture. |
| Taille de page | 50 | Deux écrans de conversation ; assez pour que le premier chargement ne pagine pas. |
| Rattrapage des non-lus | jusqu'à 200, puis on s'arrête | « Tout jusqu'au premier non lu » n'est pas tenable après une semaine d'absence. |
| Marqueur de lecture | une ligne par membre, jamais reculée | Deux appareils ne doivent pas se battre pour le curseur. |
| Invité sans compte | identifié par `MemberId`, comme partout | Règle 7 du projet : aucune dépendance à `user_id`. |
| Séparateur | retiré après 10 s de vue | Demande explicite. |

## API

### Tâche 1 — curseur sur le fil
`GET /events/{id}/messages?before={messageId}&limit=50`
- sans `before` : les `limit` derniers, ou tout depuis le premier non lu si celui-ci est
  plus loin (borné à 200) ;
- avec `before` : les `limit` messages qui précèdent celui-là ;
- réponse : `items` en ordre chronologique, `hasMore`, `oldestId`.

### Tâche 2 — marqueur de lecture
- table `message_reads` : `(EventId, MemberId)` unique, `LastReadMessageId`, `LastReadAt` ;
- `POST /events/{id}/messages/read` `{ messageId }` — n'avance jamais en arrière ;
- le fil renvoie `firstUnreadId` et `unreadCount`.

## Application

### Tâche 3 — liste inversée et chargement vers le haut
`ListView(reverse: true)` ancrée en bas, chargement de la page précédente à l'approche du
haut, sans saut de position.

### Tâche 4 — ligne « Nouveaux messages »
Posée au-dessus du premier non lu ; à l'ouverture, le fil s'ouvre là plutôt qu'en bas.

### Tâche 5 — marquage et effacement
Dix secondes après l'affichage, le marqueur avance et la ligne disparaît. Sans non-lu, le
marqueur avance dès l'ouverture.
