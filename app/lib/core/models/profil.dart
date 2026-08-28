/// Profil du compte connecté, tel que renvoyé par `GET /v1/me`.
class Profil {
  const Profil({
    required this.id,
    required this.email,
    required this.emailVerifie,
    required this.nomAffiche,
    required this.urlPhoto,
    required this.langue,
    required this.fuseau,
    required this.rolePlateforme,
    required this.aUnMotDePasse,
    required this.motDePasseAChanger,
    required this.creeLe,
    this.premiumJusquau,
  });

  factory Profil.depuisJson(Map<String, dynamic> json) => Profil(
    id: json['id'] as String,
    email: json['email'] as String?,
    emailVerifie: json['emailVerified'] as bool? ?? false,
    nomAffiche: json['displayName'] as String? ?? '',
    urlPhoto: json['avatarUrl'] as String?,
    langue: json['locale'] as String? ?? 'fr-FR',
    fuseau: json['timezone'] as String? ?? 'Europe/Paris',
    rolePlateforme: json['platformRole'] as String? ?? 'User',
    aUnMotDePasse: json['hasPassword'] as bool? ?? false,
    motDePasseAChanger: json['mustChangePassword'] as bool? ?? false,
    premiumJusquau: json['premiumUntil'] == null
        ? null
        : DateTime.parse(json['premiumUntil'] as String),
    creeLe: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String? email;
  final bool emailVerifie;
  final String nomAffiche;
  final String? urlPhoto;
  final String langue;
  final String fuseau;
  final String rolePlateforme;
  final bool aUnMotDePasse;

  /// Vrai pour le compte administrateur amorcé, jusqu'au premier changement de mot de
  /// passe (RG-ADM-10). Aucune autre action n'est permise entre-temps.
  final bool motDePasseAChanger;

  /// Échéance de la formule payante, nulle en formule gratuite (EF-PRM-05). Une échéance
  /// passée vaut gratuit : c'est la même règle que côté serveur, où aucune tâche ne vient
  /// remettre le champ à nul.
  final DateTime? premiumJusquau;

  final DateTime creeLe;

  bool get estAbonne {
    final terme = premiumJusquau;

    return terme != null && terme.isAfter(DateTime.now());
  }

  /// Vrai pour `Support` et `PlatformAdmin`. N'accorde aucun droit dans un événement
  /// (RG-ADM-01) : sert uniquement à afficher l'entrée vers le back-office.
  bool get estPersonnelPlateforme => rolePlateforme != 'User';

  bool get estAdministrateur => rolePlateforme == 'PlatformAdmin';
}

/// Session active de l'appelant.
class SessionActive {
  const SessionActive({
    required this.id,
    required this.appareil,
    required this.adresse,
    required this.creeLe,
    required this.vueLe,
    required this.estCourante,
  });

  factory SessionActive.depuisJson(Map<String, dynamic> json) => SessionActive(
    id: json['id'] as String,
    appareil: json['deviceLabel'] as String?,
    adresse: json['ipAddress'] as String?,
    creeLe: DateTime.parse(json['createdAt'] as String),
    vueLe: DateTime.parse(json['lastSeenAt'] as String),
    estCourante: json['isCurrent'] as bool? ?? false,
  );

  final String id;
  final String? appareil;
  final String? adresse;
  final DateTime creeLe;
  final DateTime vueLe;
  final bool estCourante;

  /// Nom lisible de l'appareil. L'agent utilisateur brut est illisible pour un humain.
  String get appareilLisible {
    final brut = appareil;
    if (brut == null || brut.isEmpty) {
      return 'Appareil inconnu';
    }
    if (brut.contains('Android')) return 'Android';
    if (brut.contains('iPhone') || brut.contains('iPad')) return 'iOS';
    if (brut.contains('Edg/')) return 'Edge';
    if (brut.contains('Firefox')) return 'Firefox';
    if (brut.contains('Chrome')) return 'Chrome';
    if (brut.contains('Safari')) return 'Safari';
    return brut.length > 40 ? '${brut.substring(0, 40)}…' : brut;
  }
}

/// Fiche de compte présentée dans le back-office.
class FicheCompte {
  const FicheCompte({
    required this.id,
    required this.email,
    required this.nomAffiche,
    required this.urlPhoto,
    required this.rolePlateforme,
    required this.emailVerifie,
    required this.aUnMotDePasse,
    required this.suspendu,
    required this.motifSuspension,
    required this.derniereConnexion,
    required this.sessionsActives,
    required this.creeLe,
    required this.supprimeLe,
    this.premiumJusquau,
  });

  factory FicheCompte.depuisJson(Map<String, dynamic> json) => FicheCompte(
    id: json['id'] as String,
    email: json['email'] as String?,
    nomAffiche: json['displayName'] as String? ?? '',
    urlPhoto: json['avatarUrl'] as String?,
    rolePlateforme: json['platformRole'] as String? ?? 'User',
    emailVerifie: json['emailVerified'] as bool? ?? false,
    aUnMotDePasse: json['hasPassword'] as bool? ?? false,
    suspendu: json['isSuspended'] as bool? ?? false,
    motifSuspension: json['suspensionReason'] as String?,
    derniereConnexion: json['lastLoginAt'] == null
        ? null
        : DateTime.parse(json['lastLoginAt'] as String),
    sessionsActives: json['activeSessionCount'] as int? ?? 0,
    creeLe: DateTime.parse(json['createdAt'] as String),
    supprimeLe: json['deletedAt'] == null
        ? null
        : DateTime.parse(json['deletedAt'] as String),
    premiumJusquau: json['premiumUntil'] == null
        ? null
        : DateTime.parse(json['premiumUntil'] as String),
  );

  final String id;
  final String? email;
  final String nomAffiche;
  final String? urlPhoto;
  final String rolePlateforme;
  final bool emailVerifie;
  final bool aUnMotDePasse;
  final bool suspendu;
  final String? motifSuspension;
  final DateTime? derniereConnexion;
  final int sessionsActives;
  final DateTime creeLe;
  final DateTime? supprimeLe;

  /// Échéance de la formule payante (EF-PRM-04). Affichée avant toute modification :
  /// un administrateur doit voir la formule qu'il s'apprête à changer.
  final DateTime? premiumJusquau;

  bool get estSupprime => supprimeLe != null;

  bool get estAbonne {
    final terme = premiumJusquau;

    return terme != null && terme.isAfter(DateTime.now());
  }
}

/// Page de résultats du back-office.
class PageComptes {
  const PageComptes({
    required this.elements,
    required this.total,
    required this.page,
  });

  factory PageComptes.depuisJson(Map<String, dynamic> json) => PageComptes(
    elements: [
      for (final e in json['items'] as List<dynamic>)
        FicheCompte.depuisJson(e as Map<String, dynamic>),
    ],
    total: json['total'] as int? ?? 0,
    page: json['page'] as int? ?? 1,
  );

  final List<FicheCompte> elements;
  final int total;
  final int page;
}

/// Entrée du journal d'audit.
class EntreeAudit {
  const EntreeAudit({
    required this.id,
    required this.auteur,
    required this.cible,
    required this.action,
    required this.motif,
    required this.creeLe,
  });

  factory EntreeAudit.depuisJson(Map<String, dynamic> json) => EntreeAudit(
    id: json['id'] as String,
    auteur: json['actorEmail'] as String? ?? '',
    cible: json['targetUserId'] as String?,
    action: json['action'] as String? ?? '',
    motif: json['reason'] as String?,
    creeLe: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String auteur;
  final String? cible;
  final String action;
  final String? motif;
  final DateTime creeLe;

  /// Libellé lisible d'une action. Les codes sont stables en base, pas destinés à
  /// l'affichage.
  String get actionLisible => switch (action) {
    'admin.seeded' => 'Administrateur amorcé au démarrage',
    'user.password_reset_triggered' =>
      'Réinitialisation de mot de passe déclenchée',
    'user.sessions_revoked' => 'Sessions révoquées',
    'user.suspended' => 'Compte suspendu',
    'user.unsuspended' => 'Compte réactivé',
    'user.deleted' => 'Compte supprimé',
    'user.role_changed' => 'Rôle modifié',
    'user.email_verified_by_admin' => 'Adresse vérifiée manuellement',
    'user.plan_changed' => 'Formule modifiée',
    _ => action,
  };
}
