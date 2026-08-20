/// Statut de présence (EF-PRES-01).
enum StatutPresence {
  inconnu('Unknown'),
  present('Going'),
  peutEtre('Maybe'),
  absent('NotGoing'),
  enRetard('Late'),
  partAvant('EarlyLeave');

  const StatutPresence(this.versApi);

  final String versApi;

  /// RG-PRES-02 — « arrive plus tard » et « part plus tôt » comptent comme présents,
  /// y compris dans le total des têtes.
  bool get compteCommePresent =>
      this == present || this == enRetard || this == partAvant;

  /// Un statut inconnu de cette version dégrade vers `inconnu` plutôt que de lever :
  /// une exception au milieu d'une liste rendrait l'écran inutilisable pour un ajout
  /// d'API sans conséquence.
  static StatutPresence depuisApi(String? valeur) =>
      values.firstWhere((s) => s.versApi == valeur, orElse: () => inconnu);
}

/// Rôle dans l'événement (RG-ROLE-01).
enum RoleMembre {
  proprietaire('Owner'),
  administrateur('Admin'),
  membre('Member');

  const RoleMembre(this.versApi);

  final String versApi;

  /// Peut modifier l'événement, inviter, exclure.
  bool get peutGerer => this == proprietaire || this == administrateur;

  /// RG-ROLE-01 — seul le propriétaire supprime l'événement.
  bool get peutSupprimer => this == proprietaire;

  static RoleMembre depuisApi(String? valeur) =>
      values.firstWhere((r) => r.versApi == valeur, orElse: () => membre);
}

/// Membre d'un événement.
///
/// L'API n'expose **pas** l'identifiant de compte d'un membre, et c'est délibéré : le
/// diffuser à tous les participants, invités sans compte compris, serait une fuite.
/// [aUnCompte] et [cestMoi] donnent exactement ce dont les écrans ont besoin — savoir
/// qui peut recevoir la propriété, et quelle ligne est modifiable.
class Membre {
  const Membre({
    required this.id,
    required this.nomAffiche,
    required this.avatarUrl,
    required this.statut,
    required this.heureArrivee,
    required this.heureDepart,
    required this.accompagnants,
    required this.role,
    required this.aUnCompte,
    required this.cestMoi,
  });

  final String id;
  final String nomAffiche;
  final String? avatarUrl;
  final StatutPresence statut;
  final String? heureArrivee;
  final String? heureDepart;
  final int accompagnants;
  final RoleMembre role;

  /// RG-ROLE-02 — seul un membre rattaché à un compte peut recevoir la propriété : un
  /// invité sans compte ne retrouverait pas l'événement depuis un autre appareil.
  final bool aUnCompte;

  final bool cestMoi;

  /// Têtes apportées : la personne et ses accompagnants (EF-PRES-06).
  /// L'organisateur achète pour des têtes, pas pour des comptes.
  int get tetes => statut.compteCommePresent ? 1 + accompagnants : 0;

  static Membre depuisJson(Map<String, dynamic> json) => Membre(
    id: json['id'] as String,
    nomAffiche: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    statut: StatutPresence.depuisApi(json['status'] as String?),
    heureArrivee: json['arrivalTime'] as String?,
    heureDepart: json['departureTime'] as String?,
    accompagnants: (json['extraGuests'] as num?)?.toInt() ?? 0,
    role: RoleMembre.depuisApi(json['role'] as String?),
    aUnCompte: json['hasAccount'] as bool? ?? false,
    cestMoi: json['isMe'] as bool? ?? false,
  );
}
