#!/usr/bin/env python3
"""Recette manuelle du parcours de compte et d'administration (V0.5).

Déroule le scénario de bout en bout contre une API locale et vérifie chaque attente.
Sert de filet avant les tests automatisés, et de démonstration exécutable de ce que
l'API sait faire.

    make api            # dans un autre terminal
    python3 tools/recette/parcours-comptes.py
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

API = os.environ.get("API_URL", "http://127.0.0.1:5080") + "/v1"
MAILPIT = "http://127.0.0.1:8025/api/v1"

resultats: list[tuple[bool, str]] = []
ignores: list[str] = []


def appel(methode, chemin, corps=None, jeton=None, base=API):
    requete = urllib.request.Request(f"{base}{chemin}", method=methode)
    requete.add_header("Content-Type", "application/json")
    if jeton:
        requete.add_header("Authorization", f"Bearer {jeton}")
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
    marque = "OK " if condition else "NON"
    print(f"  {marque} {libelle}{f'  [{detail}]' if detail and not condition else ''}")


def ignorer(libelle, motif):
    """Vérification non exécutable dans l'état courant de l'instance.

    Ni réussie ni échouée : la compter comme réussie mentirait, la compter comme
    échouée rendrait la recette rouge en permanence et on cesserait de la lancer.
    """
    ignores.append(f"{libelle} — {motif}")
    print(f"  -   {libelle}  [{motif}]")


def dernier_code_recu(destinataire):
    """Extrait le code du dernier courriel adressé à quelqu'un."""
    with urllib.request.urlopen(f"{MAILPIT}/messages?limit=30") as reponse:
        messages = json.load(reponse)["messages"]
    for message in messages:
        if any(d["Address"] == destinataire for d in message["To"]):
            with urllib.request.urlopen(f"{MAILPIT}/message/{message['ID']}") as reponse:
                texte = json.load(reponse)["Text"]
            trouve = re.search(r"^\s{4}(\S+)\s*$", texte, re.M)
            if trouve:
                return trouve.group(1)
    return None


suffixe = uuid.uuid4().hex[:8]
adresse = f"recette-{suffixe}@partyplan.local"
mdp = "Trombone-Nuage-42x"
mdp2 = "Cerf-Volant-Ocre-91"

print("\n--- Politique de mot de passe (RG-AUTH-01) ---")
statut, corps = appel("POST", "/auth/register",
                      {"email": f"court-{suffixe}@partyplan.local", "password": "court",
                       "displayName": "Test"})
verifier("un mot de passe trop court est refusé",
         statut == 400 and corps.get("code") == "password.too_short", f"{statut} {corps}")

statut, corps = appel("POST", "/auth/register",
                      {"email": f"comp-{suffixe}@partyplan.local", "password": "motdepasse123456",
                       "displayName": "Test"})
verifier("un mot de passe compromis est refusé malgré sa longueur",
         statut == 400 and corps.get("code") == "password.compromised", f"{statut} {corps}")

print("\n--- Inscription et vérification d'adresse (EF-AUTH-01, EF-AUTH-03) ---")
statut, corps = appel("POST", "/auth/register",
                      {"email": adresse, "password": mdp, "displayName": "Recette"})
verifier("l'inscription réussit", statut == 200 and "accessToken" in (corps or {}), f"{statut}")
jeton = corps["accessToken"]
rafraichissement = corps["refreshToken"]

statut, corps = appel("POST", "/auth/register",
                      {"email": adresse, "password": mdp, "displayName": "Doublon"})
verifier("une adresse déjà utilisée est refusée",
         statut == 409 and corps.get("code") == "auth.email_already_used", f"{statut}")

statut, profil = appel("GET", "/me", jeton=jeton)
verifier("le profil est accessible", statut == 200, f"{statut}")
verifier("l'adresse n'est pas encore vérifiée", profil["emailVerified"] is False)
verifier("le compte n'a aucun rôle plateforme", profil["platformRole"] == "User")

code = dernier_code_recu(adresse)
verifier("le courriel de vérification est capturé, non envoyé", code is not None)

statut, _ = appel("POST", "/auth/email/verify", {"token": code})
verifier("la vérification aboutit", statut == 204, f"{statut}")

statut, corps = appel("POST", "/auth/email/verify", {"token": code})
verifier("le même code ne fonctionne pas deux fois (RG-AUTH-03)",
         statut == 400 and corps.get("code") == "user.invalid_token", f"{statut}")

statut, profil = appel("GET", "/me", jeton=jeton)
verifier("l'adresse est désormais vérifiée", profil["emailVerified"] is True)

print("\n--- Profil (EF-USR-02, EF-USR-07) ---")
statut, profil = appel("PATCH", "/me", {"displayName": "Recette Modifiée"}, jeton=jeton)
verifier("le nom affiché est modifiable",
         statut == 200 and profil["displayName"] == "Recette Modifiée", f"{statut}")

statut, corps = appel("PATCH", "/me", {"timezone": "Mars/Olympus"}, jeton=jeton)
verifier("un fuseau horaire inconnu est refusé",
         statut == 400 and corps.get("code") == "user.timezone_invalid", f"{statut} {corps}")

statut, corps = appel("PATCH", "/me", {"displayName": ""}, jeton=jeton)
verifier("un nom vide est refusé",
         statut == 400 and corps.get("code") == "user.display_name_invalid", f"{statut}")

print("\n--- Sessions (EF-AUTH-09, EF-AUTH-10) ---")
statut, sessions = appel("GET", "/me/sessions", jeton=jeton)
verifier("la session courante est listée et identifiée",
         statut == 200 and len(sessions) == 1 and sessions[0]["isCurrent"] is True, f"{statut}")

statut, nouveaux = appel("POST", "/auth/refresh", {"refreshToken": rafraichissement})
verifier("le rafraîchissement aboutit", statut == 200, f"{statut}")
verifier("le jeton de rafraîchissement a tourné",
         nouveaux["refreshToken"] != rafraichissement)

statut, corps = appel("POST", "/auth/refresh", {"refreshToken": rafraichissement})
verifier("l'ancien jeton de rafraîchissement est refusé (rotation)",
         statut == 400 and corps.get("code") == "auth.invalid_refresh_token", f"{statut}")
jeton = nouveaux["accessToken"]

print("\n--- Mot de passe (EF-AUTH-04, EF-AUTH-05, RG-AUTH-04, RG-AUTH-06) ---")
statut_connu, _ = appel("POST", "/auth/password/forgot", {"email": adresse})
statut_inconnu, _ = appel("POST", "/auth/password/forgot",
                          {"email": f"inexistant-{suffixe}@partyplan.local"})
verifier("la réponse est identique pour une adresse connue et inconnue (RG-AUTH-04)",
         statut_connu == statut_inconnu == 202, f"{statut_connu} / {statut_inconnu}")

code = dernier_code_recu(adresse)
statut, _ = appel("POST", "/auth/password/reset", {"token": code, "newPassword": mdp2})
verifier("la réinitialisation aboutit", statut == 204, f"{statut}")

statut, _ = appel("POST", "/auth/login", {"email": adresse, "password": mdp})
verifier("l'ancien mot de passe ne fonctionne plus", statut == 400, f"{statut}")

statut, session = appel("POST", "/auth/login", {"email": adresse, "password": mdp2})
verifier("le nouveau mot de passe fonctionne", statut == 200, f"{statut}")
jeton = session["accessToken"]

statut, corps = appel("POST", "/auth/password/change",
                      {"currentPassword": "mauvais-mot-de-passe", "newPassword": "Girafe-Bleue-77x"},
                      jeton=jeton)
verifier("changer le mot de passe exige l'ancien",
         statut == 400 and corps.get("code") == "user.wrong_password", f"{statut}")

statut, _ = appel("POST", "/auth/password/change",
                  {"currentPassword": mdp2, "newPassword": "Girafe-Bleue-77x"}, jeton=jeton)
verifier("le changement de mot de passe aboutit", statut == 204, f"{statut}")

print("\n--- RGPD (EF-USR-09, EF-USR-10, RG-USR-05) ---")
statut, session = appel("POST", "/auth/login", {"email": adresse, "password": "Girafe-Bleue-77x"})
jeton = session["accessToken"]

requete = urllib.request.Request(f"{API}/me/export")
requete.add_header("Authorization", f"Bearer {jeton}")
with urllib.request.urlopen(requete) as reponse:
    export = json.load(reponse)
verifier("l'export contient le compte et les sessions",
         "compte" in export and "sessions" in export)
verifier("l'export ne contient aucune empreinte de mot de passe",
         "passwordHash" not in json.dumps(export) and "argon2" not in json.dumps(export))

statut, corps = appel("DELETE", "/me", {"emailConfirmation": "pas-la-bonne@x.fr"}, jeton=jeton)
verifier("la suppression exige la bonne adresse en confirmation",
         statut == 400 and corps.get("code") == "user.confirmation_mismatch", f"{statut}")

statut, _ = appel("DELETE", "/me", {"emailConfirmation": adresse}, jeton=jeton)
verifier("la suppression aboutit", statut == 204, f"{statut}")

statut, _ = appel("POST", "/auth/login", {"email": adresse, "password": "Girafe-Bleue-77x"})
verifier("le compte supprimé ne peut plus se connecter", statut == 400, f"{statut}")

statut, corps = appel("POST", "/auth/register",
                      {"email": adresse, "password": mdp, "displayName": "Réinscription"})
verifier("l'adresse est libérée : la réinscription est possible (RG-USR-06)",
         statut == 200, f"{statut} {corps}")

print("\n--- Retrait de la double authentification (ADR 0007) ---")
adresse_sans2fa = f"sans2fa-{suffixe}@partyplan.local"
statut, session = appel("POST", "/auth/register",
                        {"email": adresse_sans2fa, "password": mdp, "displayName": "Sans 2FA"})
verifier("un compte de contrôle est créé", statut == 200, f"{statut} {session}")
jeton_sans2fa = (session or {}).get("accessToken")

statut, profil_sans2fa = appel("GET", "/me", jeton=jeton_sans2fa)
verifier("le profil ne déclare plus de double authentification",
         statut == 200 and "totpEnabled" not in profil_sans2fa, f"{statut}")

for methode, chemin in (("POST", "/auth/totp/setup"),
                        ("POST", "/auth/totp/activate"),
                        ("DELETE", "/auth/totp"),
                        ("POST", "/auth/totp/recovery-codes"),
                        ("POST", "/auth/mfa/verify")):
    statut, _ = appel(methode, chemin, {"code": "000000", "password": mdp}, jeton=jeton_sans2fa)
    verifier(f"{methode} {chemin} n'existe plus", statut == 404, f"{statut}")

statut, connexion = appel("POST", "/auth/login",
                          {"email": adresse_sans2fa, "password": mdp})
verifier("la connexion ouvre directement une session",
         statut == 200 and connexion.get("accessToken"), f"{statut}")
verifier("aucun défi de second facteur n'est annoncé",
         "requiresSecondFactor" not in connexion and "challengeToken" not in connexion)

print("\n--- Administration (EF-ADM-01 à EF-ADM-09, RG-ADM-05) ---")
# Cette recette change elle-même le mot de passe imposé (RG-ADM-10). Au second passage
# sur la même base, c'est donc le mot de passe changé qui vaut : les deux sont essayés,
# sans quoi la recette ne serait jouable qu'une fois par base.
MDP_ADMIN_AMORCE = "MotDePasseDeDeveloppement"
MDP_ADMIN_CHANGE = "Girouette-Safran-88"

for mdp_admin in (MDP_ADMIN_AMORCE, MDP_ADMIN_CHANGE):
    statut, session = appel("POST", "/auth/login",
                            {"email": "admin@partyplan.local", "password": mdp_admin})
    if statut == 200:
        break
verifier("l'administrateur amorcé peut se connecter", statut == 200, f"{statut}")

if statut == 200:
    jeton_amorce = session["accessToken"]
    statut, profil_amorce = appel("GET", "/me", jeton=jeton_amorce)

    # RG-ADM-10 ne s'observe que sur une instance jamais amorcée : une fois le mot de
    # passe changé, l'obligation ne revient pas. Sur une base de développement déjà
    # utilisée, ces deux points sont donc ignorés plutôt que déclarés faux.
    # `AdminDeDeveloppementTests` les couvre en repartant d'une base vierge.
    if profil_amorce.get("mustChangePassword") is True:
        verifier("le compte amorcé doit changer son mot de passe (RG-ADM-10)", True)

        statut, corps = appel("GET", "/admin/users?pageSize=1", jeton=jeton_amorce)
        verifier("tant que le mot de passe n'est pas changé, aucune action n'est permise",
                 statut == 403 and corps.get("code") in ("auth.must_change_password", None),
                 f"{statut} {corps}")

        statut, _ = appel("POST", "/auth/password/change",
                          {"currentPassword": MDP_ADMIN_AMORCE,
                           "newPassword": MDP_ADMIN_CHANGE}, jeton=jeton_amorce)
        verifier("le changement de mot de passe imposé aboutit", statut == 204, f"{statut}")

        statut, session = appel("POST", "/auth/login",
                                {"email": "admin@partyplan.local",
                                 "password": MDP_ADMIN_CHANGE})
        verifier("la reconnexion avec le nouveau mot de passe fonctionne",
                 statut == 200, f"{statut}")
    else:
        ignorer("RG-ADM-10, changement de mot de passe imposé",
                "mot de passe déjà changé sur cette instance ; relancer après make reset-db")

    # ADR 0007 : le mot de passe changé, l'administration s'ouvre. Aucun enrôlement à
    # franchir — c'est cette exigence qui rendait le back-office inatteignable à son
    # seul administrateur.
    jeton_amorce = session["accessToken"]

    statut, _ = appel("GET", "/admin/users?pageSize=1", jeton=jeton_amorce)
    verifier("le mot de passe changé, l'administration s'ouvre sans second facteur",
             statut == 200, f"{statut}")

if statut != 200:
    print("\nArrêt : sans session d'administration, la suite est intestable.")
else:
    jeton_admin = session["accessToken"]

    statut, profil = appel("GET", "/me", jeton=jeton_admin)
    verifier("il porte le rôle PlatformAdmin", profil["platformRole"] == "PlatformAdmin")

    statut, page = appel("GET", "/admin/users?pageSize=5", jeton=jeton_admin)
    verifier("la liste des comptes est accessible", statut == 200 and "items" in (page or {}),
             f"{statut}")

    statut, page = appel("GET", "/admin/users?search=recette", jeton=jeton_admin)
    verifier("la recherche par nom fonctionne", statut == 200 and page["total"] >= 1, f"{statut}")

    cible = next(u for u in page["items"] if u["email"] == adresse)
    verifier("la fiche ne contient aucune empreinte de mot de passe",
             "passwordHash" not in cible)

    statut, _ = appel("POST", f"/admin/users/{cible['id']}/password-reset", jeton=jeton_admin)
    verifier("l'administrateur peut déclencher une réinitialisation", statut == 202, f"{statut}")
    verifier("le lien part vers l'adresse du compte, non à l'administrateur",
             dernier_code_recu(adresse) is not None)

    statut, corps = appel("POST", f"/admin/users/{cible['id']}/suspend", {"reason": ""},
                          jeton=jeton_admin)
    verifier("la suspension exige un motif",
             statut == 400 and corps.get("code") == "admin.reason_required", f"{statut}")

    statut, _ = appel("POST", f"/admin/users/{cible['id']}/suspend",
                      {"reason": "Recette automatisée"}, jeton=jeton_admin)
    verifier("la suspension aboutit", statut == 204, f"{statut}")

    statut, corps = appel("POST", "/auth/login", {"email": adresse, "password": mdp})
    verifier("un compte suspendu ne peut plus se connecter (RG-ADM-07)",
             statut == 403 and corps.get("code") == "auth.account_suspended", f"{statut}")

    statut, _ = appel("POST", f"/admin/users/{cible['id']}/unsuspend", jeton=jeton_admin)
    verifier("la réactivation aboutit", statut == 204, f"{statut}")

    statut, _ = appel("POST", "/auth/login", {"email": adresse, "password": mdp})
    verifier("le compte réactivé peut se reconnecter", statut == 200, f"{statut}")

    statut, moi = appel("GET", "/me", jeton=jeton_admin)
    statut, corps = appel("DELETE", f"/admin/users/{moi['id']}", jeton=jeton_admin)
    verifier("un administrateur ne peut pas se supprimer lui-même (RG-ADM-03)",
             statut == 422 and corps.get("code") == "admin.self_action_refused", f"{statut}")

    statut, corps = appel("PATCH", f"/admin/users/{moi['id']}/role", {"role": "User"},
                          jeton=jeton_admin)
    verifier("un administrateur ne peut pas se révoquer lui-même (RG-ADM-03)",
             statut == 422, f"{statut}")

    statut, corps = appel("PATCH", f"/admin/users/{cible['id']}/role", {"role": "Sorcier"},
                          jeton=jeton_admin)
    verifier("un rôle inconnu est refusé",
             statut == 400 and corps.get("code") == "admin.unknown_role", f"{statut}")

    # ADR 0007 : la promotion n'exige plus de second facteur.
    statut, page_sans2fa = appel("GET", f"/admin/users?search=sans2fa-{suffixe}",
                                 jeton=jeton_admin)
    cible_sans2fa = page_sans2fa["items"][0]

    statut, _ = appel("PATCH", f"/admin/users/{cible_sans2fa['id']}/role", {"role": "Support"},
                      jeton=jeton_admin)
    verifier("la promotion aboutit sans second facteur (ADR 0007)", statut == 204, f"{statut}")

    statut, session_support = appel("POST", "/auth/login",
                                    {"email": adresse_sans2fa, "password": mdp})
    jeton_support = session_support["accessToken"]

    statut, _ = appel("GET", "/admin/users?pageSize=1", jeton=jeton_support)
    verifier("un Support peut consulter la liste des comptes", statut == 200, f"{statut}")

    statut, _ = appel("DELETE", f"/admin/users/{cible['id']}", jeton=jeton_support)
    verifier("un Support ne peut pas supprimer un compte (RG-ADM-05)", statut == 403, f"{statut}")

    statut, _ = appel("POST", f"/admin/users/{cible['id']}/suspend", {"reason": "test"},
                      jeton=jeton_support)
    verifier("un Support ne peut pas suspendre un compte (RG-ADM-05)", statut == 403, f"{statut}")

    statut, journal = appel("GET", "/admin/audit?pageSize=20", jeton=jeton_admin)
    verifier("le journal d'audit est consultable", statut == 200 and len(journal) > 0, f"{statut}")
    actions = {e["action"] for e in journal}
    verifier("l'amorçage figure au journal", "admin.seeded" in actions, str(actions))
    verifier("la suspension figure au journal", "user.suspended" in actions, str(actions))
    verifier("le motif est conservé",
             any(e["reason"] == "Recette automatisée" for e in journal))

    statut, _ = appel("GET", "/admin/users?pageSize=1")
    verifier("un appelant anonyme est refusé sur l'administration", statut == 401, f"{statut}")

    statut, indicateurs = appel("GET", "/admin/metrics", jeton=jeton_admin)
    verifier("les indicateurs d'instance sont exposés",
             statut == 200 and indicateurs["totalUsers"] > 0, f"{statut}")

echecs = [libelle for ok, libelle in resultats if not ok]
print(f"\n{len(resultats) - len(echecs)} / {len(resultats)} vérifications passées"
      + (f", {len(ignores)} ignorée(s)" if ignores else ""))
for libelle in ignores:
    print("  ignorée :", libelle)
if echecs:
    print("\nÉchecs :")
    for libelle in echecs:
        print("  -", libelle)
    sys.exit(1)
