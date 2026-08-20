#!/usr/bin/env python3
"""Recette du parcours événementiel (V1.0, lots 1.1 à 1.4).

Déroule « créer une soirée → inviter → répondre » de bout en bout contre une API locale.

    make api            # dans un autre terminal
    python3 tools/recette/parcours-evenement.py
"""

import json
import sys
import urllib.error
import urllib.request
import uuid

API = "http://127.0.0.1:5080/v1"

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
    suffixe = uuid.uuid4().hex[:8]
    statut, session = appel("POST", "/auth/register", {
        "email": f"{nom.lower()}-{suffixe}@partyplan.local",
        "password": "Trombone-Nuage-42x",
        "displayName": nom,
    })
    return session["accessToken"] if statut == 200 else None


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

print("\n--- Participation sans compte (EF-INV-04, RG-INV-05) ---")
jetons_invites = {}
for nom, presence in [("Lucas", "Going"), ("Emma", "Maybe"), ("Rémi", "Late"),
                      ("Thomas", "NotGoing")]:
    statut, adhesion = appel("POST", f"/join/{jeton_lien}",
                             {"displayName": nom, "status": presence},
                             cle_idempotence=uuid.uuid4().hex)
    verifier(f"{nom} rejoint sans compte, statut « {presence} »", statut == 200, f"{statut}")
    if statut == 200 and adhesion.get("guestToken"):
        jetons_invites[nom] = adhesion["guestToken"]

verifier("un jeton d'invité est remis à chacun", len(jetons_invites) == 4,
         str(len(jetons_invites)))

statut, _ = appel("POST", f"/join/{jeton_lien}", {"displayName": "", "status": "Going"},
                  cle_idempotence=uuid.uuid4().hex)
verifier("un prénom vide est refusé", statut == 400, f"{statut}")

if jetons_invites:
    jeton_lucas = jetons_invites["Lucas"]
    statut, _ = appel("GET", f"/events/{evenement_id}", jeton=jeton_lucas)
    verifier("un invité voit l'événement qu'il a rejoint", statut == 200, f"{statut}")

    statut, autre = creer({"name": "Autre", "startsAt": "2026-09-01T18:00:00Z"}, organisateur)
    statut, _ = appel("GET", f"/events/{autre['id']}", jeton=jeton_lucas)
    verifier("un invité ne voit aucun autre événement (EF-INV-04)", statut == 404, f"{statut}")

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
verifier("les invités sans compte y figurent",
         sum(1 for m in membres if not m["hasAccount"]) == 4)

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
participant = compte("Lucas")
appel("POST", f"/join/{jeton_lien}", {"displayName": "Lucas (compte)", "status": "Going"},
      jeton=participant, cle_idempotence=uuid.uuid4().hex)

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
appel("POST", f"/join/{jeton_lien}", {"displayName": "Lucie", "status": "Going"},
      jeton=repreneur, cle_idempotence=uuid.uuid4().hex)

statut, membres = appel("GET", f"/events/{evenement_id}/members", jeton=organisateur)
cible = next((m for m in membres if m["displayName"] == "Lucie"), None)
verifier("le repreneur est bien membre", cible is not None)

if cible:
    statut, corps = appel("POST", f"/events/{evenement_id}/members/{cible['id']}/transfer-ownership",
                          jeton=repreneur, cle_idempotence=uuid.uuid4().hex)
    verifier("un membre ordinaire ne transfère pas la propriété",
             statut == 403 and corps.get("code") == "event.only_owner_transfers", f"{statut}")

    invite_sans_compte = next((m for m in membres if not m["hasAccount"]), None)
    if invite_sans_compte:
        statut, corps = appel(
            "POST",
            f"/events/{evenement_id}/members/{invite_sans_compte['id']}/transfer-ownership",
            jeton=organisateur, cle_idempotence=uuid.uuid4().hex)
        verifier("un invité sans compte ne peut pas devenir propriétaire",
                 statut == 422 and corps.get("code") == "event.transfer_needs_account",
                 f"{statut}")

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

statut, corps = appel("POST", f"/join/{jeton_lien}", {"displayName": "Trop tard", "status": "Going"},
                      cle_idempotence=uuid.uuid4().hex)
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

statut, _ = appel("POST", f"/join/{jeton2}",
                  {"displayName": "Sans clé", "status": "Going"})
verifier("la clé d'idempotence est obligatoire sur l'adhésion",
         statut == 400, f"{statut}")

cle_adhesion = uuid.uuid4().hex
appel("POST", f"/join/{jeton2}", {"displayName": "Rejouée", "status": "Going"},
      cle_idempotence=cle_adhesion)
statut, _ = appel("POST", f"/join/{jeton2}", {"displayName": "Rejouée", "status": "Going"},
                  cle_idempotence=cle_adhesion)
verifier("une adhésion rejouée est acceptée", statut == 200, f"{statut}")

statut, membres2 = appel("GET", f"/events/{id2}/members", jeton=evt2)
verifier("une adhésion rejouée ne crée pas un second membre",
         len([m for m in membres2 if m["displayName"] == "Rejouée"]) == 1)

print("\n--- Rejoindre par code court (EF-INV-03) ---")
# Le code court doit permettre de rejoindre, pas seulement de regarder : l'aperçu ne
# contient aucun jeton (RG-INV-04), et sans cet endpoint il serait une impasse.
statut, adhesion_code = appel(
    "POST", f"/join/code/{code2[5:].lower()}",
    {"displayName": "Par le code", "status": "Going"},
    cle_idempotence=uuid.uuid4().hex)
verifier("le code court permet de rejoindre", statut == 200, f"{statut}")
verifier("un jeton d'invité est remis",
         statut == 200 and bool(adhesion_code.get("guestToken")))

statut, _ = appel("POST", "/join/code/ZZZZZZ",
                  {"displayName": "Intrus", "status": "Going"},
                  cle_idempotence=uuid.uuid4().hex)
verifier("un code court inconnu ne laisse pas rejoindre", statut == 404, f"{statut}")

print("\n--- Conversion d'un invité en compte (EF-AUTH-11) ---")
statut, adhesion_conv = appel(
    "POST", f"/join/{jeton2}", {"displayName": "Léa", "status": "Going"},
    cle_idempotence=uuid.uuid4().hex)
jeton_invite = adhesion_conv.get("guestToken") if statut == 200 else None
verifier("l'invitée sans compte reçoit un jeton", jeton_invite is not None)

nouveau = compte("Lea")
statut, resultat = appel("POST", "/auth/guest-claim",
                         {"guestToken": jeton_invite}, jeton=nouveau)
verifier("le rattachement aboutit", statut == 200, f"{statut}")
verifier("une participation est rattachée",
         statut == 200 and resultat.get("linked") == 1, f"{resultat}")

statut, siens = appel("GET", "/events", jeton=nouveau)
verifier("l'événement rejoint sans compte apparaît dans la liste du compte",
         statut == 200 and any(e["id"] == id2 for e in siens))

statut, membres_conv = appel("GET", f"/events/{id2}/members", jeton=evt2)
verifier("aucun doublon de membre après conversion",
         len([m for m in membres_conv if m["displayName"] == "Léa"]) == 1)

statut, _ = appel("POST", "/auth/guest-claim", {"guestToken": "inconnu"}, jeton=nouveau)
verifier("un jeton d'invité inconnu ne produit pas d'erreur", statut == 200, f"{statut}")

statut, _ = appel("POST", "/auth/guest-claim", {"guestToken": jeton_invite})
verifier("le rattachement exige une session", statut == 401, f"{statut}")

print("\n--- Parcours en trois interactions (EF-INV-04) ---")
evt3 = compte("Zoe")
statut, soiree3 = creer(
    {"name": "Trois gestes", "startsAt": "2026-09-25T20:00:00Z"}, evt3)
id3 = soiree3["id"]
statut, inv3 = appel("GET", f"/events/{id3}/invitation", jeton=evt3)

# 1. Ouverture du lien : l'aperçu, sans session ni adresse.
statut, apercu3 = appel("GET", f"/join/{inv3['token']}")
verifier("l'aperçu s'ouvre sans session", statut == 200, f"{statut}")
verifier("RG-INV-04 : l'aperçu ne liste pas les membres", "members" not in apercu3)
verifier("RG-INV-04 : l'aperçu ne révèle aucun jeton", "token" not in apercu3)

# 2. et 3. Prénom puis statut, en un seul appel : deux écrans, aucune adresse saisie.
statut, adhesion3 = appel("POST", f"/join/{inv3['token']}",
                          {"displayName": "Zoé", "status": "Going"},
                          cle_idempotence=uuid.uuid4().hex)
verifier("l'adhésion aboutit sans adresse e-mail", statut == 200, f"{statut}")

statut, tableau3 = appel("GET", f"/events/{id3}",
                         jeton=adhesion3.get("guestToken") if statut == 200 else None)
verifier("le tableau de bord est atteint avec le seul jeton d'invité",
         statut == 200 and tableau3.get("name") == "Trois gestes", f"{statut}")

echecs = [libelle for ok, libelle in resultats if not ok]
print(f"\n{len(resultats) - len(echecs)} / {len(resultats)} vérifications passées")
if echecs:
    print("\nÉchecs :")
    for libelle in echecs:
        print("  -", libelle)
    sys.exit(1)
