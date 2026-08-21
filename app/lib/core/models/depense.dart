/// Mode de constitution de l'assiette d'une dépense (`EF-DEP-02`).
///
/// Figé à la création (`RG-DEP-02`) : une arrivée tardive ne redistribue pas une
/// dépense déjà payée. Redistribuer après coup serait la meilleure façon de rendre les
/// soldes incompréhensibles.
enum ModeAssiette {
  /// Tous ceux qui sont comptés présents au moment de la saisie. Cas courant.
  tousLesPresents('AllPresent', 'Tous les présents'),

  /// Choix explicite des participants, à parts égales.
  selection('Selection', 'Certains seulement'),

  /// Choix explicite, avec un poids par personne : deux parts pour celui qui dort
  /// sur place, une pour les autres.
  partsPersonnalisees('Custom', 'Parts inégales');

  const ModeAssiette(this.versApi, this.libelle);

  /// Nom attendu par l'API. Anglais, comme tous les identifiants de base.
  final String versApi;

  final String libelle;
}

/// Part demandée pour une personne, à la création d'une dépense.
class PartDemandee {
  const PartDemandee(this.membreId, this.part);

  final String membreId;

  /// Poids relatif. Toujours 1 hors mode [ModeAssiette.partsPersonnalisees].
  final int part;

  Map<String, dynamic> versJson() => {'memberId': membreId, 'share': part};
}

/// Part effectivement attribuée, telle que le serveur l'a calculée.
///
/// Le montant vient du serveur et n'est jamais recalculé côté application : la
/// répartition au centime avec la règle des plus grands restes est son affaire
/// (`§6.2`), et un second calcul créerait une divergence invisible jusqu'au litige.
class PartDepense {
  const PartDepense({
    required this.membreId,
    required this.nom,
    required this.part,
    required this.montant,
  });

  factory PartDepense.depuisJson(Map<String, dynamic> json) => PartDepense(
    membreId: json['memberId'] as String,
    nom: json['displayName'] as String? ?? '',
    part: json['share'] as int? ?? 1,
    montant: (json['amount'] as num?)?.toDouble() ?? 0,
  );

  final String membreId;
  final String nom;
  final int part;
  final double montant;
}

/// Dépense dans la liste (`EF-DEP-04`).
class Depense {
  const Depense({
    required this.id,
    required this.libelle,
    required this.montant,
    required this.payeurMembreId,
    required this.payeurNom,
    required this.date,
    required this.nombreParticipants,
    required this.issueDesCourses,
  });

  factory Depense.depuisJson(Map<String, dynamic> json) => Depense(
    id: json['id'] as String,
    libelle: json['label'] as String? ?? '',
    montant: (json['amount'] as num?)?.toDouble() ?? 0,
    payeurMembreId: json['paidByMemberId'] as String? ?? '',
    payeurNom: json['paidByDisplayName'] as String? ?? '',
    date: DateTime.parse(json['spentAt'] as String),
    nombreParticipants: json['participantCount'] as int? ?? 0,
    issueDesCourses: json['fromShoppingItem'] as bool? ?? false,
  );

  final String id;
  final String libelle;
  final double montant;
  final String payeurMembreId;
  final String payeurNom;
  final DateTime date;
  final int nombreParticipants;

  /// Vrai lorsque la dépense a été engendrée par un achat de la liste de courses
  /// (`EF-CRS-07`). Les deux origines cohabitent dans la même liste : sans ce repère,
  /// personne ne comprend d'où sort une dépense qu'il n'a pas saisie.
  final bool issueDesCourses;
}

/// Détail d'une dépense : payeur, participants, part de chacun (`EF-DEP-05`).
class DetailDepense {
  const DetailDepense({
    required this.id,
    required this.libelle,
    required this.montant,
    required this.payeurMembreId,
    required this.payeurNom,
    required this.date,
    required this.issueDesCourses,
    required this.nombreRevisions,
    required this.parts,
  });

  factory DetailDepense.depuisJson(Map<String, dynamic> json) => DetailDepense(
    id: json['id'] as String,
    libelle: json['label'] as String? ?? '',
    montant: (json['amount'] as num?)?.toDouble() ?? 0,
    payeurMembreId: json['paidByMemberId'] as String? ?? '',
    payeurNom: json['paidByDisplayName'] as String? ?? '',
    date: DateTime.parse(json['spentAt'] as String),
    issueDesCourses: json['fromShoppingItem'] as bool? ?? false,
    nombreRevisions: json['revisionCount'] as int? ?? 0,
    parts: [
      for (final part in json['shares'] as List<dynamic>? ?? const [])
        PartDepense.depuisJson(part as Map<String, dynamic>),
    ],
  );

  final String id;
  final String libelle;
  final double montant;
  final String payeurMembreId;
  final String payeurNom;
  final DateTime date;
  final bool issueDesCourses;

  /// Nombre de modifications conservées (`RG-DEP-04`). L'afficher évite qu'un montant
  /// change sans que personne ne puisse le constater.
  final int nombreRevisions;

  final List<PartDepense> parts;

  /// Vrai lorsque tous les participants ne portent pas le même poids.
  ///
  /// L'écran le signale : deux personnes qui doivent des sommes différentes sur une
  /// même dépense se demanderaient sinon si le calcul est faux.
  bool get partsInegales =>
      parts.map((p) => p.part).toSet().length > 1;
}

/// Liste des dépenses et ses totaux.
class PageDepenses {
  const PageDepenses({
    required this.total,
    required this.maPart,
    required this.depenses,
  });

  factory PageDepenses.depuisJson(Map<String, dynamic> json) => PageDepenses(
    total: (json['total'] as num?)?.toDouble() ?? 0,
    maPart: (json['myShare'] as num?)?.toDouble() ?? 0,
    depenses: [
      for (final depense in json['items'] as List<dynamic>? ?? const [])
        Depense.depuisJson(depense as Map<String, dynamic>),
    ],
  );

  /// Total dépensé pour l'événement, toutes origines confondues.
  final double total;

  /// Part cumulée de l'appelant. Ce n'est pas ce qu'il doit : les remboursements
  /// tiennent compte de ce qu'il a lui-même avancé (`§6.3`).
  final double maPart;

  final List<Depense> depenses;

  bool get estVide => depenses.isEmpty;
}
