/// Solde d'un membre (`§6.3`).
///
/// Positif : on lui doit de l'argent. Négatif : il en doit. Le signe vient du serveur
/// et n'est jamais recalculé côté application — aucun solde n'est persisté, tout est
/// recalculé à la demande (`RG-RMB-02`), et un second calcul créerait une divergence
/// invisible jusqu'au litige.
class Solde {
  const Solde({
    required this.membreId,
    required this.nom,
    required this.photo,
    required this.montant,
  });

  factory Solde.depuisJson(Map<String, dynamic> json) => Solde(
    membreId: json['memberId'] as String,
    nom: json['displayName'] as String? ?? '',
    photo: json['avatarUrl'] as String?,
    montant: (json['amount'] as num?)?.toDouble() ?? 0,
  );

  final String membreId;
  final String nom;

  /// Photo du membre. `null` : l'avatar affiche ses initiales.
  final String? photo;

  final double montant;

  bool get onLuiDoit => montant > 0;

  bool get ilDoit => montant < 0;

  bool get estSolde => montant == 0;
}

/// Remboursement proposé (`EF-RMB-02`) ou déjà effectué (`EF-RMB-03`).
class Reglement {
  const Reglement({
    required this.id,
    required this.deMembreId,
    required this.deNom,
    required this.dePhoto,
    required this.versMembreId,
    required this.versNom,
    required this.versPhoto,
    required this.montant,
    required this.effectue,
    required this.meConcerne,
  });

  factory Reglement.depuisJson(Map<String, dynamic> json) => Reglement(
    id: json['id'] as String?,
    deMembreId: json['fromMemberId'] as String,
    deNom: json['fromDisplayName'] as String? ?? '',
    dePhoto: json['fromAvatarUrl'] as String?,
    versMembreId: json['toMemberId'] as String,
    versNom: json['toDisplayName'] as String? ?? '',
    versPhoto: json['toAvatarUrl'] as String?,
    montant: (json['amount'] as num?)?.toDouble() ?? 0,
    effectue: json['done'] as bool? ?? false,
    meConcerne: json['involvesMe'] as bool? ?? false,
  );

  /// Nul tant que le règlement n'est que proposé : il n'existe alors nulle part.
  final String? id;

  final String deMembreId;
  final String deNom;

  /// Photo de qui doit. `null` : l'avatar affiche ses initiales.
  final String? dePhoto;
  final String versMembreId;
  final String versNom;

  /// Photo de qui reçoit.
  final String? versPhoto;
  final double montant;
  final bool effectue;

  /// Vrai lorsque l'appelant est le débiteur ou le créancier. Ce sont les seules
  /// lignes sur lesquelles il a quelque chose à faire.
  final bool meConcerne;
}

/// Vue complète des remboursements.
class PageReglements {
  const PageReglements({
    required this.soldes,
    required this.proposes,
    required this.effectues,
    required this.monSolde,
    required this.invariantRespecte,
  });

  factory PageReglements.depuisJson(Map<String, dynamic> json) =>
      PageReglements(
        soldes: [
          for (final s in json['balances'] as List<dynamic>? ?? const [])
            Solde.depuisJson(s as Map<String, dynamic>),
        ],
        proposes: [
          for (final r in json['proposed'] as List<dynamic>? ?? const [])
            Reglement.depuisJson(r as Map<String, dynamic>),
        ],
        effectues: [
          for (final r in json['done'] as List<dynamic>? ?? const [])
            Reglement.depuisJson(r as Map<String, dynamic>),
        ],
        monSolde: (json['myBalance'] as num?)?.toDouble() ?? 0,
        invariantRespecte: json['invariantHolds'] as bool? ?? true,
      );

  final List<Solde> soldes;
  final List<Reglement> proposes;
  final List<Reglement> effectues;
  final double monSolde;

  /// Faux lorsque la somme des soldes n'est pas nulle (`IV-02`). L'interface le signale
  /// au lieu d'afficher des chiffres qu'on sait faux (`RG-RMB-04`).
  final bool invariantRespecte;

  bool get rienARegler => proposes.isEmpty && effectues.isEmpty;
}
