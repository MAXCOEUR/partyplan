/// Un service tiers, tel que présenté à l'écran de rattachement (EF-AUTH-08).
class MoyenTiers {
  const MoyenTiers({
    required this.identifiant,
    required this.disponible,
    required this.rattache,
  });

  factory MoyenTiers.depuisJson(Map<String, dynamic> json) => MoyenTiers(
    identifiant: json['provider'] as String,
    disponible: json['configured'] as bool? ?? false,
    rattache: json['linked'] as bool? ?? false,
  );

  /// Identifiant technique, en minuscules : `google`, `apple`.
  final String identifiant;

  /// Vrai si l'instance dispose des clés du service. Indépendant de [rattache] : une
  /// clé retirée ne doit pas rendre un compte indétachable.
  final bool disponible;

  final bool rattache;

  /// Nom affiché. Un identifiant inconnu est rendu tel quel plutôt que masqué : mieux
  /// vaut un libellé inélégant qu'un service invisible.
  String get libelle => switch (identifiant) {
    'google' => 'Google',
    'apple' => 'Apple',
    _ => identifiant,
  };
}

/// Moyens de connexion du compte, renvoyés par `GET /v1/auth/providers`.
class MoyensConnexion {
  const MoyensConnexion({
    required this.aUnMotDePasse,
    required this.fournisseurs,
  });

  factory MoyensConnexion.depuisJson(Map<String, dynamic> json) =>
      MoyensConnexion(
        aUnMotDePasse: json['hasPassword'] as bool? ?? false,
        fournisseurs: ((json['providers'] as List<dynamic>?) ?? const [])
            .map((brut) => MoyenTiers.depuisJson(brut as Map<String, dynamic>))
            .toList(growable: false),
      );

  final bool aUnMotDePasse;
  final List<MoyenTiers> fournisseurs;

  /// Nombre de moyens de connexion, mot de passe compris.
  int get nombre =>
      (aUnMotDePasse ? 1 : 0) + fournisseurs.where((f) => f.rattache).length;

  /// Vrai si [fournisseur] peut être détaché sans enfermer la personne dehors.
  ///
  /// Le serveur applique la même règle (`external.would_lock_out`) : la vérifier ici
  /// évite d'afficher un bouton dont on sait qu'il échouera.
  bool peutDetacher(MoyenTiers fournisseur) =>
      fournisseur.rattache && nombre > 1;
}
