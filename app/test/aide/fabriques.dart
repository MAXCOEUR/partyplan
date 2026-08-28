import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/invitation.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/models/profil.dart';

/// Date fixe : un test ne doit jamais dépendre de l'heure à laquelle il tourne.
final debutFictif = DateTime(2026, 9, 12, 20);

/// Profil ordinaire, en formule gratuite.
///
/// Nécessaire dès qu'un test monte un écran affichant la formule — l'accueil et le
/// profil. Sans surcharge, le vrai profil serait demandé au réseau et laisserait un
/// minuteur en attente à la fin du test.
Profil profilDeTest({
  String id = 'u1',
  String role = 'User',
  DateTime? premiumJusquau,
}) => Profil(
  id: id,
  email: 'moi@partyplan.local',
  emailVerifie: true,
  nomAffiche: 'Maxence',
  urlPhoto: null,
  langue: 'fr-FR',
  fuseau: 'Europe/Paris',
  rolePlateforme: role,
  aUnMotDePasse: true,
  motDePasseAChanger: false,
  creeLe: DateTime(2026, 8, 1),
  premiumJusquau: premiumJusquau,
);

EvenementDeLaListe itemListe({
  String id = 'e1',
  String nom = 'Crémaillère chez Léa',
  DateTime? debut,
  int invites = 8,
  int presents = 5,
  RoleMembre monRole = RoleMembre.membre,
  StatutPresence monStatut = StatutPresence.present,
  bool estPasse = false,
}) => EvenementDeLaListe(
  id: id,
  nom: nom,
  debut: debut ?? debutFictif,
  fin: null,
  adresse: '12 rue des Lilas, Lyon',
  imageCouverture: null,
  invites: invites,
  presents: presents,
  monRole: monRole,
  monStatut: monStatut,
  estPasse: estPasse,
);

ResumeEvenement resume({
  String id = 'e1',
  String nom = 'Crémaillère chez Léa',
  String? adresse = '12 rue des Lilas, Lyon',
  DateTime? debut,
  int membres = 8,
  int presents = 5,
  int peutEtre = 2,
  bool adhesionsOuvertes = true,
}) => ResumeEvenement(
  id: id,
  nom: nom,
  description: null,
  debut: debut ?? debutFictif,
  fin: null,
  adresse: adresse,
  imageCouverture: null,
  nombreMembres: membres,
  nombrePresents: presents,
  nombrePeutEtre: peutEtre,
  adhesionsOuvertes: adhesionsOuvertes,
);

Membre membre({
  String id = 'm1',
  String nom = 'Léa',
  StatutPresence statut = StatutPresence.present,
  RoleMembre role = RoleMembre.membre,
  int accompagnants = 0,
  bool aUnCompte = true,
  bool cestMoi = false,
}) => Membre(
  id: id,
  nomAffiche: nom,
  avatarUrl: null,
  statut: statut,
  heureArrivee: null,
  heureDepart: null,
  accompagnants: accompagnants,
  role: role,
  aUnCompte: aUnCompte,
  cestMoi: cestMoi,
);

Invitation invitation({
  String jeton = 'JETON-SECRET',
  String codeCourt = 'PLAN-K7M2X9',
  String lien = 'https://partyplan.test/join/JETON-SECRET',
  bool adhesionsOuvertes = true,
}) => Invitation(
  jeton: jeton,
  codeCourt: codeCourt,
  lien: lien,
  adhesionsOuvertes: adhesionsOuvertes,
);

ApercuInvitation apercu({
  String nom = 'Crémaillère chez Léa',
  int participants = 8,
  bool adhesionsOuvertes = true,
  bool dejaMembre = false,
}) => ApercuInvitation(
  nom: nom,
  debut: debutFictif,
  fin: null,
  adresse: '12 rue des Lilas, Lyon',
  description: null,
  nombreParticipants: participants,
  adhesionsOuvertes: adhesionsOuvertes,
  dejaMembre: dejaMembre,
);
