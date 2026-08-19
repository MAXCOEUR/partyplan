# ADR 0003 — Nommage des domaines

- Date : 19/08/2026
- Statut : accepté

## Décision

Tout est regroupé sous `partyplan.maxencecoeur.fr` (et non sous `app.maxencecoeur.fr`),
afin de pouvoir basculer l'ensemble vers `partyplan.fr` sans réécrire les configurations.

| Rôle | Domaine |
|---|---|
| Application Flutter Web / PWA | `partyplan.maxencecoeur.fr` |
| API ASP.NET Core | `api.partyplan.maxencecoeur.fr` |
| Fichiers statiques, images de couverture | `cdn.partyplan.maxencecoeur.fr` |
| Administration (optionnel, plus tard) | `admin.partyplan.maxencecoeur.fr` |

Cible ultérieure : `partyplan.fr`, `api.partyplan.fr`, `cdn.partyplan.fr`.

## Temps réel : pas de sous-domaine dédié

SignalR est exposé sur `api.partyplan.maxencecoeur.fr/hubs/*` plutôt que sur un
`ws.partyplan.maxencecoeur.fr`. Raisons :

- même origine que les appels REST : une seule règle CORS, un seul jeton d'authentification
  transmis de la même manière ;
- pas de certificat ni d'entrée de reverse proxy supplémentaires ;
- SignalR négocie automatiquement WebSocket puis bascule en Server-Sent Events ou
  long polling — un sous-domaine « ws » deviendrait un nom trompeur en cas de repli.

## Point d'attention certificats

Ces noms sont des sous-domaines de **deuxième niveau**. Un certificat joker
`*.maxencecoeur.fr` ne couvre pas `api.partyplan.maxencecoeur.fr`.

Deux options :
1. certificats Let's Encrypt individuels par nom, challenge HTTP-01 — le plus simple ;
2. joker `*.partyplan.maxencecoeur.fr`, qui impose un challenge DNS-01 (donc un accès
   API au registrar / à Cloudflare).

Option 1 retenue au démarrage, option 2 si le nombre de sous-domaines augmente.
