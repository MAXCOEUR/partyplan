/// Invitation d'un événement : lien, code court, état des adhésions.
class Invitation {
  const Invitation({
    required this.jeton,
    required this.codeCourt,
    required this.lien,
    required this.adhesionsOuvertes,
  });

  final String jeton;
  final String codeCourt;
  final String lien;
  final bool adhesionsOuvertes;

  static Invitation depuisJson(Map<String, dynamic> json) => Invitation(
    jeton: json['token'] as String,
    codeCourt: json['shortCode'] as String,
    lien: json['joinUrl'] as String,
    adhesionsOuvertes: json['joinEnabled'] as bool,
  );
}

/// Aperçu restreint, visible sans session.
///
/// RG-INV-04 — nom, date, lieu et nombre de participants. **Ni liste nominative, ni
/// dépenses, ni jeton.** Le modèle ne porte volontairement aucun autre champ : ce qui
/// n'existe pas ici ne peut pas fuiter dans un écran.
class ApercuInvitation {
  const ApercuInvitation({
    required this.nom,
    required this.debut,
    required this.fin,
    required this.adresse,
    required this.description,
    required this.nombreParticipants,
    required this.adhesionsOuvertes,
    required this.dejaMembre,
  });

  final String nom;
  final DateTime debut;
  final DateTime? fin;
  final String? adresse;
  final String? description;
  final int nombreParticipants;

  /// EF-INV-06 — quand les arrivées sont fermées, l'aperçu reste lisible et explique le
  /// refus plutôt que de renvoyer une erreur opaque.
  final bool adhesionsOuvertes;

  final bool dejaMembre;

  static ApercuInvitation depuisJson(Map<String, dynamic> json) => ApercuInvitation(
    nom: json['name'] as String,
    debut: DateTime.parse(json['startsAt'] as String).toLocal(),
    fin: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String).toLocal(),
    adresse: json['address'] as String?,
    description: json['description'] as String?,
    nombreParticipants: (json['participantCount'] as num).toInt(),
    adhesionsOuvertes: json['joinEnabled'] as bool,
    dejaMembre: json['alreadyMember'] as bool? ?? false,
  );
}
