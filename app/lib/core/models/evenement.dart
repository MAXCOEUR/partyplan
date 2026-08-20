import 'membre.dart';

/// Événement tel qu'il apparaît dans la liste d'accueil (`EventListItem`).
///
/// Type distinct du détail : la liste porte le rôle et le statut de l'appelant, que le
/// détail ne renvoie pas. Les confondre obligerait chaque carte à charger le détail.
class EvenementDeLaListe {
  const EvenementDeLaListe({
    required this.id,
    required this.nom,
    required this.debut,
    required this.fin,
    required this.adresse,
    required this.imageCouverture,
    required this.invites,
    required this.presents,
    required this.monRole,
    required this.monStatut,
    required this.estPasse,
  });

  final String id;
  final String nom;
  final DateTime debut;
  final DateTime? fin;
  final String? adresse;
  final String? imageCouverture;
  final int invites;
  final int presents;
  final RoleMembre monRole;
  final StatutPresence monStatut;

  /// Décidé par le serveur, jamais recalculé ici : l'horloge d'un téléphone peut être
  /// fausse, et une soirée passerait alors du mauvais côté de la liste.
  final bool estPasse;

  static EvenementDeLaListe depuisJson(Map<String, dynamic> json) =>
      EvenementDeLaListe(
        id: json['id'] as String,
        nom: json['name'] as String,
        debut: DateTime.parse(json['startsAt'] as String).toLocal(),
        fin: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String).toLocal(),
        adresse: json['address'] as String?,
        imageCouverture: json['coverImageUrl'] as String?,
        invites: (json['invited'] as num).toInt(),
        presents: (json['present'] as num).toInt(),
        monRole: RoleMembre.depuisApi(json['myRole'] as String?),
        monStatut: StatutPresence.depuisApi(json['myStatus'] as String?),
        estPasse: json['isPast'] as bool,
      );
}

/// Vue de synthèse d'un événement (`EventSummary`).
class ResumeEvenement {
  const ResumeEvenement({
    required this.id,
    required this.nom,
    required this.description,
    required this.debut,
    required this.fin,
    required this.adresse,
    required this.imageCouverture,
    required this.nombreMembres,
    required this.nombrePresents,
    required this.nombrePeutEtre,
    required this.adhesionsOuvertes,
  });

  final String id;
  final String nom;
  final String? description;
  final DateTime debut;
  final DateTime? fin;
  final String? adresse;
  final String? imageCouverture;
  final int nombreMembres;

  /// RG-PRES-04 — présents et têtes sont deux décomptes distincts. Celui-ci compte les
  /// personnes ; les têtes, accompagnants compris, se calculent sur la liste des
  /// membres. Les confondre fausserait toutes les quantités de courses.
  final int nombrePresents;

  /// RG-PRES-03 — les « peut-être » sont comptés à part, jamais dans les présents.
  final int nombrePeutEtre;

  final bool adhesionsOuvertes;

  bool get estAVenir => debut.isAfter(DateTime.now());

  /// EF-EVT-02 — sans fin saisie, l'événement se termine implicitement à +12 heures.
  DateTime get finEffective => fin ?? debut.add(const Duration(hours: 12));

  static ResumeEvenement depuisJson(Map<String, dynamic> json) => ResumeEvenement(
    id: json['id'] as String,
    nom: json['name'] as String,
    description: json['description'] as String?,
    debut: DateTime.parse(json['startsAt'] as String).toLocal(),
    fin: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String).toLocal(),
    adresse: json['address'] as String?,
    imageCouverture: json['coverImageUrl'] as String?,
    nombreMembres: (json['memberCount'] as num).toInt(),
    nombrePresents: (json['presentCount'] as num).toInt(),
    nombrePeutEtre: (json['maybeCount'] as num).toInt(),
    adhesionsOuvertes: json['joinEnabled'] as bool,
  );
}
