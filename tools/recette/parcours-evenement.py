#!/usr/bin/env python3
"""Recette du parcours événementiel (V1.0, lots 1.2 à 1.4).

Déroule « créer une soirée → inviter → répondre » de bout en bout contre une API locale.

Le parcours invité sans compte n'existe plus : l'ADR 0006 exige un compte pour toute
nouvelle adhésion. Le nom du membre vient du profil, jamais du corps de la requête, et
son statut initial est « Unknown » — jamais présumé présent (RG-PRES-01).

    make api            # dans un autre terminal
    python3 tools/recette/parcours-evenement.py
"""

import json
import os
import sys
import urllib.error
import urllib.request
import uuid

API = os.environ.get("API_URL", "http://127.0.0.1:5080") + "/v1"

resultats: list[tuple[bool, str]] = []


def appel(methode, chemin, corps=None, jeton=None, cle_idempotence=None):
    requete = urllib.request.Request(f"{API}{chemin}", method=methode)
    requete.add_header("Content-Type", "application/json")
    if jeton:
        requete.add_header("Authorization", f"Bearer {jeton}")
    if cle_idempotence:
        requete.add_header("Idempotency-Key", cle_idempotence)
    donnees = json.dumps(corps).encode() if corps is not None else None
    try:
        with urllib.request.urlopen(requete, donnees) as reponse:
            brut = reponse.read()
            return reponse.status, json.loads(brut) if brut else None
    except urllib.error.HTTPError as erreur:
        brut = erreur.read()
        return erreur.code, json.loads(brut) if brut else None


def verifier(libelle, condition, detail=""):
    resultats.append((bool(condition), libelle))
    print(f"  {'OK ' if condition else 'NON'} {libelle}"
          f"{f'  [{detail}]' if detail and not condition else ''}")


def compte(nom):
    """Crée un compte et renvoie son jeton d'accès. Le nom affiché vient du profil.

    Ce scénario ouvre une quinzaine de comptes : la limitation de débit de RG-AUTH-05
    peut être épuisée si une autre recette vient de tourner sur la même API. Mieux vaut
    le dire que laisser une trace Python illisible dix vérifications plus loin.
    """
    suffixe = uuid.uuid4().hex[:8]
    statut, session = appel("POST", "/auth/register", {
        "email": f"{nom.lower()}-{suffixe}@partyplan.local",
        "password": "Trombone-Nuage-42x",
        "displayName": nom,
    })
    if statut == 429:
        print(f"\nArrêt : limitation de débit atteinte à la création du compte « {nom} ».")
        print("Redémarrer l'API, ou attendre la fenêtre de RG-AUTH-05, puis relancer.")
        sys.exit(2)
    if statut != 200:
        print(f"\nArrêt : impossible de créer le compte « {nom} » ({statut}).")
        sys.exit(2)
    return session["accessToken"]


def rejoindre(cible, jeton, cle=None):
    """Rejoint par lien ou par code court. Aucun corps : ni nom, ni statut (EF-INV-04)."""
    return appel("POST", cible, jeton=jeton,
                 cle_idempotence=cle or uuid.uuid4().hex)


print("\n--- Création d'un événement (EF-EVT-01, EF-EVT-02) ---")
organisateur = compte("Maxence")
verifier("un compte organisateur est créé", organisateur is not None)

def creer(corps, jeton, cle=None):
    """Crée un événement. L'en-tête d'idempotence est obligatoire (§8.1)."""
    return appel("POST", "/events", corps, jeton=jeton,
                 cle_idempotence=cle or uuid.uuid4().hex)


statut, corps = appel("POST", "/events", {
    "name": "Sans clé", "startsAt": "2026-08-29T18:00:00Z"}, jeton=organisateur)
verifier("la clé d'idempotence est obligatoire sur la création",
         statut == 400 and corps.get("code") == "idempotency.key_required", f"{statut}")

cle_partagee = uuid.uuid4().hex
corps_soiree = {
    "name": "Anniversaire de Maxence",
    "description": "Barbecue puis soirée.",
    "startsAt": "2026-08-29T18:00:00Z",
    "address": "Replonges",
}

statut, evenement = creer(corps_soiree, organisateur, cle_partagee)
verifier("la création aboutit", statut == 200, f"{statut}")

statut, rejeu = creer(corps_soiree, organisateur, cle_partagee)
verifier("une réémission rejoue la réponse sans créer de doublon",
         statut == 200 and rejeu["id"] == evenement["id"], f"{statut}")

statut, conflit = creer({**corps_soiree, "name": "Autre nom"}, organisateur, cle_partagee)
verifier("la même clé avec un corps différent est un conflit",
         statut == 409 and conflit.get("code") == "idempotency.key_reused", f"{statut}")
verifier("le créateur est compté présent",
         evenement["presentCount"] == 1 and evenement["memberCount"] == 1)

evenement_id = evenement["id"]

statut, corps = creer({"name": "  ", "startsAt": "2026-08-29T18:00:00Z"}, organisateur)
verifier("un nom vide est refusé",
         statut == 400 and corps.get("code") == "event.name_required", f"{statut}")

statut, corps = creer({"name": "Incohérent", "startsAt": "2026-08-29T18:00:00Z",
                       "endsAt": "2026-08-28T18:00:00Z"}, organisateur)
verifier("une fin antérieure au début est refusée",
         statut == 400 and corps.get("code") == "event.end_before_start", f"{statut}")

statut, liste = appel("GET", "/events", jeton=organisateur)
verifier("l'événement apparaît dans la liste avec le rôle propriétaire",
         statut == 200 and any(e["id"] == evenement_id and e["myRole"] == "Owner" for e in liste))

print("\n--- Invitation (EF-INV-01 à EF-INV-06, RG-INV-02, RG-INV-04) ---")
statut, invitation = appel("GET", f"/events/{evenement_id}/invitation", jeton=organisateur)
verifier("le lien, le code court et l'état d'ouverture sont exposés", statut == 200, f"{statut}")

jeton_lien = invitation["token"]
code_court = invitation["shortCode"]

verifier("le code court suit le format PLAN-XXXXXX",
         code_court.startswith("PLAN-") and len(code_court) == 11, code_court)
verifier("le code court n'emploie aucun caractère ambigu",
         not any(c in code_court[5:] for c in "IO01"), code_court)
verifier("le jeton du lien est suffisamment long", len(jeton_lien) >= 22, str(len(jeton_lien)))

statut, apercu = appel("GET", f"/join/{jeton_lien}")
verifier("l'aperçu public est lisible sans compte", statut == 200, f"{statut}")

champs = set(apercu.keys())
verifier("l'aperçu ne révèle ni membres, ni dépenses, ni jeton (RG-INV-04)",
         not (champs & {"members", "expenses", "inviteToken", "shortCode"}), str(champs))

statut, _ = appel("GET", f"/events/{evenement_id}")
verifier("l'événement reste inaccessible sans avoir rejoint", statut == 401, f"{statut}")

statut, resolu = appel("GET", f"/join/code/{code_court[5:].lower()}")
verifier("le code court se résout en minuscules et sans préfixe", statut == 200, f"{statut}")

statut, _ = appel("GET", "/join/code/PLAN-ZZZZZZ")
verifier("un code inexistant renvoie 404", statut == 404, f"{statut}")

print("\n--- Participation avec compte (EF-INV-04, RG-INV-05, ADR 0006) ---")
statut, _ = rejoindre(f"/join/{jeton_lien}", None)
verifier("une adhésion anonyme est refusée (ADR 0006)", statut == 401, f"{statut}")

jetons = {}
for nom in ("Lucas", "Emma", "Rémi", "Thomas"):
    jetons[nom] = compte(nom)
    statut, adhesion = rejoindre(f"/join/{jeton_lien}", jetons[nom])
    verifier(f"{nom} rejoint avec son compte", statut == 200, f"{statut}")
    verifier(f"l'adhésion de {nom} renvoie son identifiant de membre",
             statut == 200 and adhesion.get("memberId"), str(adhesion))

statut, membres = appel("GET", f"/events/{evenement_id}/members", jeton=organisateur)
noms = {m["displayName"] for m in membres}
verifier("le nom du membre vient du profil, non du corps de la requête",
         {"Lucas", "Emma", "Rémi", "Thomas"} <= noms, str(noms))
verifier("tous les membres ont un compte (ADR 0006)",
         all(m["hasAccount"] for m in membres))

arrivants = [m for m in membres if m["displayName"] in ("Lucas", "Emma", "Rémi", "Thomas")]
verifier("le statut initial est « Unknown », jamais présumé présent (RG-PRES-01)",
         all(m["status"] == "Unknown" for m in arrivants),
         str({m["displayName"]: m["status"] for m in arrivants}))

# Chacun déclare ensuite sa présence : c'est son geste, pas celui de l'organisateur.
for nom, presence in (("Lucas", "Going"), ("Emma", "Maybe"),
                      ("Rémi", "Late"), ("Thomas", "NotGoing")):
    statut, _ = appel("PATCH", f"/events/{evenement_id}/members/me",
                      {"status": presence}, jeton=jetons[nom])
    verifier(f"{nom} déclare « {presence} »", statut == 200, f"{statut}")

statut, _ = appel("GET", f"/events/{evenement_id}", jeton=jetons["Lucas"])
verifier("un membre voit l'événement qu'il a rejoint", statut == 200, f"{statut}")

statut, autre = creer({"name": "Autre", "startsAt": "2026-09-01T18:00:00Z"}, organisateur)
statut, _ = appel("GET", f"/events/{autre['id']}", jeton=jetons["Lucas"])
verifier("un membre ne voit aucun autre événement (cloisonnement)", statut == 404, f"{statut}")

print("\n--- Présences (EF-PRES-01 à EF-PRES-06, RG-PRES-02, RG-PRES-03) ---")
statut, evenement = appel("GET", f"/events/{evenement_id}", jeton=organisateur)
verifier("« arrive plus tard » compte comme présent (RG-PRES-02)",
         evenement["presentCount"] == 3, str(evenement["presentCount"]))
verifier("« peut-être » est compté à part (RG-PRES-03)",
         evenement["maybeCount"] == 1, str(evenement["maybeCount"]))
verifier("tous les invités sont dénombrés",
         evenement["memberCount"] == 5, str(evenement["memberCount"]))

statut, membres = appel("GET", f"/events/{evenement_id}/members", jeton=organisateur)
verifier("la liste nominative est visible d'un membre", statut == 200, f"{statut}")
verifier("chaque ligne porte un rôle et un statut",
         all("role" in m and "status" in m for m in membres))

statut, moi = appel("PATCH", f"/events/{evenement_id}/members/me",
                    {"status": "Late", "arrivalTime": "22:00:00", "extraGuests": 2},
                    jeton=organisateur)
verifier("chacun modifie son propre statut", statut == 200 and moi["status"] == "Late", f"{statut}")
verifier("l'heure d'arrivée est conservée", moi["arrivalTime"] == "22h00",
         str(moi.get("arrivalTime")))

statut, corps = appel("PATCH", f"/events/{evenement_id}/members/me",
                      {"status": "Peut-être-que-oui"}, jeton=organisateur)
verifier("un statut inconnu est refusé",
         statut == 400 and corps.get("code") == "attendance.unknown_status", f"{statut}")

statut, corps = appel("PATCH", f"/events/{evenement_id}/members/me",
                      {"status": "Going", "extraGuests": 99}, jeton=organisateur)
verifier("le nombre d'accompagnants est plafonné",
         statut == 400 and corps.get("code") == "attendance.too_many_guests", f"{statut}")

print("\n--- Rôles (RG-ROLE-01 à RG-ROLE-03) ---")
participant = compte("Nino")
rejoindre(f"/join/{jeton_lien}", participant)

statut, corps = appel("PATCH", f"/events/{evenement_id}", {"name": "Détourné"}, jeton=participant)
verifier("un membre ordinaire ne modifie pas l'événement",
         statut == 403 and corps.get("code") == "event.not_allowed_to_manage", f"{statut}")

statut, _ = appel("DELETE", f"/events/{evenement_id}?force=true", jeton=participant)
verifier("un membre ordinaire ne supprime pas l'événement", statut == 403, f"{statut}")

statut, corps = appel("DELETE", f"/events/{evenement_id}/members/me", jeton=organisateur)
verifier("le propriétaire ne peut pas quitter sans transférer (RG-ROLE-02)",
         statut == 422 and corps.get("code") == "event.owner_must_transfer", f"{statut}")

statut, _ = appel("DELETE", f"/events/{evenement_id}/members/me", jeton=participant)
verifier("un membre ordinaire peut quitter", statut == 204, f"{statut}")

print("\n--- Transfert de propriété (RG-ROLE-02) ---")
repreneur = compte("Lucie")
rejoindre(f"/join/{jeton_lien}", repreneur)

statut, membres = appel("GET", f"/events/{evenement_id}/members", jeton=organisateur)
cible = next((m for m in membres if m["displayName"] == "Lucie"), None)
verifier("le repreneur est bien membre", cible is not None)

if cible:
    statut, corps = appel("POST", f"/events/{evenement_id}/members/{cible['id']}/transfer-ownership",
                          jeton=repreneur, cle_idempotence=uuid.uuid4().hex)
    verifier("un membre ordinaire ne transfère pas la propriété",
             statut == 403 and corps.get("code") == "event.only_owner_transfers", f"{statut}")

    # La garde « event.transfer_needs_account » n'est plus atteignable par la recette :
    # depuis l'ADR 0006 aucune ligne sans compte ne peut être créée. Elle protège les
    # lignes historiques et reste couverte par OwnershipTransferTests.

    statut, _ = appel("POST", f"/events/{evenement_id}/members/{cible['id']}/transfer-ownership",
                      jeton=organisateur, cle_idempotence=uuid.uuid4().hex)
    verifier("le transfert aboutit", statut == 204, f"{statut}")

    statut, membres = appel("GET", f"/events/{evenement_id}/members", jeton=repreneur)
    roles = {m["displayName"]: m["role"] for m in membres}
    verifier("le repreneur devient propriétaire", roles.get("Lucie") == "Owner",
             str(roles.get("Lucie")))
    verifier("l'ancien propriétaire devient administrateur, non membre ordinaire",
             roles.get("Organisateur") == "Admin", str(roles.get("Organisateur")))

    statut, _ = appel("DELETE", f"/events/{evenement_id}/members/me", jeton=organisateur)
    verifier("l'ancien propriétaire peut désormais quitter", statut == 204, f"{statut}")

    # La suite du scénario reprend la main avec le nouveau propriétaire.
    organisateur = repreneur

print("\n--- Fermeture et régénération (EF-INV-05, EF-INV-06) ---")
statut, _ = appel("PATCH", f"/events/{evenement_id}/join-enabled", {"joinEnabled": False},
                  jeton=organisateur)
verifier("les arrivées se ferment", statut == 204, f"{statut}")

retardataire = compte("Tardif")
statut, corps = rejoindre(f"/join/{jeton_lien}", retardataire)
verifier("un événement fermé refuse les arrivées",
         statut == 422 and corps.get("code") == "invitation.closed", f"{statut}")

statut, apercu = appel("GET", f"/join/{jeton_lien}")
verifier("l'aperçu reste lisible pour expliquer le refus",
         statut == 200 and apercu["joinEnabled"] is False, f"{statut}")

appel("PATCH", f"/events/{evenement_id}/join-enabled", {"joinEnabled": True}, jeton=organisateur)

statut, nouvelle = appel("POST", f"/events/{evenement_id}/invitation/rotate", jeton=organisateur)
verifier("la régénération aboutit", statut == 200, f"{statut}")
verifier("le jeton change", nouvelle["token"] != jeton_lien)
verifier("le code court change aussi", nouvelle["shortCode"] != code_court)

statut, _ = appel("GET", f"/join/{jeton_lien}")
verifier("l'ancien lien ne fonctionne plus", statut == 404, f"{statut}")

print("\n--- Suppression (EF-EVT-07, RG-EVT-02) ---")
statut, corps = appel("DELETE", f"/events/{evenement_id}", jeton=organisateur)
verifier("la suppression exige une confirmation renforcée",
         statut == 422 and corps.get("code") == "event.settlements_pending", f"{statut}")

statut, _ = appel("DELETE", f"/events/{evenement_id}?force=true", jeton=organisateur)
verifier("la suppression confirmée aboutit", statut == 204, f"{statut}")

statut, _ = appel("GET", f"/events/{evenement_id}", jeton=organisateur)
verifier("l'événement supprimé devient inaccessible", statut == 404, f"{statut}")

print("\n--- Idempotence des écritures différables (NF-OFFLINE-01) ---")
evt2 = compte("Ida")
statut, soiree2 = creer(
    {"name": "Rejeu", "startsAt": "2026-09-20T20:00:00Z"}, evt2)
id2 = soiree2["id"]
statut, inv2 = appel("GET", f"/events/{id2}/invitation", jeton=evt2)
jeton2, code2 = inv2["token"], inv2["shortCode"]

rejoueuse = compte("Rejouee")
statut, _ = appel("POST", f"/join/{jeton2}", jeton=rejoueuse)
verifier("la clé d'idempotence est obligatoire sur l'adhésion",
         statut == 400, f"{statut}")

cle_adhesion = uuid.uuid4().hex
rejoindre(f"/join/{jeton2}", rejoueuse, cle=cle_adhesion)
statut, _ = rejoindre(f"/join/{jeton2}", rejoueuse, cle=cle_adhesion)
verifier("une adhésion rejouée est acceptée", statut == 200, f"{statut}")

# RG-INV-05 : le rejeu ne doit ni créer un doublon, ni toucher à la présence déjà posée.
statut, _ = appel("PATCH", f"/events/{id2}/members/me", {"status": "Going"}, jeton=rejoueuse)
statut, _ = rejoindre(f"/join/{jeton2}", rejoueuse)
statut, membres2 = appel("GET", f"/events/{id2}/members", jeton=evt2)
lignes = [m for m in membres2 if m["displayName"] == "Rejouee"]
verifier("une adhésion rejouée ne crée pas un second membre", len(lignes) == 1,
         str(len(lignes)))
verifier("une adhésion rejouée ne remet pas la présence à zéro (RG-INV-05)",
         bool(lignes) and lignes[0]["status"] == "Going",
         str(lignes[0]["status"]) if lignes else "aucune ligne")

print("\n--- Rejoindre par code court (EF-INV-03) ---")
# Le code court doit permettre de rejoindre, pas seulement de regarder : l'aperçu ne
# contient aucun jeton (RG-INV-04), et sans cet endpoint il serait une impasse.
par_le_code = compte("Camille")
statut, adhesion_code = rejoindre(f"/join/code/{code2[5:].lower()}", par_le_code)
verifier("le code court permet de rejoindre", statut == 200, f"{statut}")
verifier("l'adhésion par code renvoie l'événement et le membre",
         statut == 200 and adhesion_code.get("eventId") == id2, str(adhesion_code))

statut, _ = rejoindre("/join/code/ZZZZZZ", par_le_code)
verifier("un code court inconnu ne laisse pas rejoindre", statut == 404, f"{statut}")

statut, _ = rejoindre(f"/join/code/{code2[5:].lower()}", None)
verifier("le code court n'ouvre rien sans compte (ADR 0006)", statut == 401, f"{statut}")

print("\n--- Le parcours invité a disparu (ADR 0006) ---")
# La conversion d'invité en compte (ancien EF-AUTH-11, /auth/guest-claim) est supprimée :
# il n'y a plus d'invité à convertir. Ce qui doit rester vrai, c'est qu'aucune porte
# dérobée ne subsiste.
statut, _ = appel("POST", "/auth/guest-claim", {"guestToken": "inconnu"})
verifier("l'endpoint de conversion d'invité n'existe plus", statut == 404, f"{statut}")

statut, _ = appel("POST", f"/join/{jeton2}", cle_idempotence=uuid.uuid4().hex)
verifier("rejoindre sans session est refusé", statut == 401, f"{statut}")

print("\n--- Parcours d'invitation de bout en bout (EF-INV-04, EF-AUTH-11) ---")
evt3 = compte("Zoe")
statut, soiree3 = creer(
    {"name": "Trois gestes", "startsAt": "2026-09-25T20:00:00Z"}, evt3)
id3 = soiree3["id"]
statut, inv3 = appel("GET", f"/events/{id3}/invitation", jeton=evt3)

# 1. Ouverture du lien : l'aperçu, sans session.
statut, apercu3 = appel("GET", f"/join/{inv3['token']}")
verifier("l'aperçu s'ouvre sans session", statut == 200, f"{statut}")
verifier("RG-INV-04 : l'aperçu ne liste pas les membres", "members" not in apercu3)
verifier("RG-INV-04 : l'aperçu ne révèle aucun jeton", "token" not in apercu3)
verifier("l'aperçu annonce le nombre de participants",
         "participantCount" in apercu3 or "memberCount" in apercu3, str(set(apercu3)))

# 2. Création du compte depuis l'aperçu — c'est ce que porte le retour d'invitation.
invitee = compte("Zoé")
verifier("un compte se crée depuis l'aperçu", invitee is not None)

# 3. Adhésion avec le compte : ni nom ni statut transmis.
statut, adhesion3 = rejoindre(f"/join/{inv3['token']}", invitee)
verifier("l'adhésion aboutit avec le compte", statut == 200, f"{statut}")

statut, tableau3 = appel("GET", f"/events/{id3}", jeton=invitee)
verifier("le tableau de bord est atteint aussitôt",
         statut == 200 and tableau3.get("name") == "Trois gestes", f"{statut}")

statut, membres3 = appel("GET", f"/events/{id3}/members", jeton=invitee)
ligne = next((m for m in membres3 if m["displayName"] == "Zoé"), None)
verifier("le nom affiché est celui du profil", ligne is not None)
verifier("la présence reste à déclarer (RG-PRES-01)",
         ligne is not None and ligne["status"] == "Unknown",
         str(ligne["status"]) if ligne else "aucune ligne")

echecs = [libelle for ok, libelle in resultats if not ok]
print(f"\n{len(resultats) - len(echecs)} / {len(resultats)} vérifications passées")
if echecs:
    print("\nÉchecs :")
    for libelle in echecs:
        print("  -", libelle)
    sys.exit(1)
