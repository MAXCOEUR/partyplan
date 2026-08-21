/// Catégories de la liste de courses (`EF-CRS-02`).
///
/// Quatre, jamais plus : une liste de courses de soirée n'a pas besoin d'une
/// taxonomie, et le rangement devient un travail dès qu'il y a le choix.
enum CategorieCourse {
  boissons('Drinks', 'Boissons'),
  nourriture('Food', 'Nourriture'),
  materiel('Supplies', 'Matériel'),
  autres('Other', 'Autres');

  const CategorieCourse(this.versApi, this.libelle);

  /// Identifiant attendu par l'API. Anglais, comme tous les identifiants de base :
  /// envoyer le libellé français ferait échouer la création en « catégorie inconnue ».
  final String versApi;

  /// Libellé affiché.
  final String libelle;

  /// Analyse la valeur reçue de l'API.
  ///
  /// Une valeur inconnue tombe sur [autres] au lieu de lever : une cinquième catégorie
  /// ajoutée côté serveur laisserait sinon l'écran en erreur chez tous les clients
  /// déjà installés.
  static CategorieCourse depuisApi(String? valeur) => values.firstWhere(
    (categorie) => categorie.versApi == valeur,
    orElse: () => autres,
  );
}

/// Avancement de la liste (`EF-CRS-09`).
class AvancementCourses {
  const AvancementCourses({
    required this.total,
    required this.pris,
    required this.achetes,
  });

  factory AvancementCourses.depuisJson(Map<String, dynamic> json) =>
      AvancementCourses(
        total: json['total'] as int? ?? 0,
        pris: json['claimed'] as int? ?? 0,
        achetes: json['purchased'] as int? ?? 0,
      );

  final int total;
  final int pris;
  final int achetes;

  bool get estVide => total == 0;

  bool get toutAchete => total > 0 && achetes == total;
}

/// Article de la liste de courses.
///
/// L'attributaire est désigné par sa ligne de membre, jamais par un compte : un invité
/// sans compte s'attribue un article comme n'importe qui d'autre (`EF-INV-04`).
class ArticleCourse {
  const ArticleCourse({
    required this.id,
    required this.nom,
    required this.quantite,
    required this.unite,
    required this.categorie,
    required this.membreAttributaire,
    required this.nomAttributaire,
    required this.prisParMoi,
    required this.estAchete,
    required this.quantiteObtenue,
    required this.quantiteRestante,
    required this.prixEstime,
    required this.prixPaye,
    required this.note,
  });

  factory ArticleCourse.depuisJson(Map<String, dynamic> json) => ArticleCourse(
    id: json['id'] as String,
    nom: json['name'] as String? ?? '',
    quantite: (json['quantity'] as num?)?.toDouble() ?? 0,
    unite: json['unit'] as String?,
    categorie: CategorieCourse.depuisApi(json['category'] as String?),
    membreAttributaire: json['assignedMemberId'] as String?,
    nomAttributaire: json['assignedDisplayName'] as String?,
    prisParMoi: json['assignedToMe'] as bool? ?? false,
    estAchete: json['isPurchased'] as bool? ?? false,
    quantiteObtenue: (json['purchasedQuantity'] as num?)?.toDouble(),
    quantiteRestante: (json['remainingQuantity'] as num?)?.toDouble() ?? 0,
    prixEstime: (json['estimatedPrice'] as num?)?.toDouble(),
    prixPaye: (json['actualPrice'] as num?)?.toDouble(),
    note: json['note'] as String?,
  );

  final String id;
  final String nom;
  final double quantite;
  final String? unite;
  final CategorieCourse categorie;
  final String? membreAttributaire;
  final String? nomAttributaire;

  /// Vrai lorsque l'article est attribué à l'appelant. Distinct de [estPris] : seul le
  /// propriétaire de l'attribution peut la retirer (`EF-CRS-04`).
  final bool prisParMoi;

  final bool estAchete;
  final double? quantiteObtenue;
  final double quantiteRestante;

  /// Prix estimé. Indicatif seulement : il n'entre dans aucun calcul de répartition
  /// (`RG-CRS-03`).
  final double? prixEstime;

  /// Prix réellement payé. Sa saisie engendre une dépense (`EF-CRS-07`).
  final double? prixPaye;

  final String? note;

  bool get estPris => membreAttributaire != null;

  /// Achat incomplet : il reste à obtenir (`RG-CRS-02`). L'afficher évite qu'un article
  /// à moitié acheté passe pour réglé.
  bool get achatPartiel => estAchete && quantiteRestante > 0;

  /// Quantité et unité en un seul libellé : « 24 bouteilles », « 50 ».
  ///
  /// Les quantités entières s'affichent sans décimale : « 24 » et non « 24.0 ».
  String get quantiteLisible {
    final nombre = quantite == quantite.roundToDouble()
        ? quantite.toStringAsFixed(0)
        : quantite.toString();

    return unite == null || unite!.isEmpty ? nombre : '$nombre ${unite!}';
  }
}

/// Liste de courses complète : avancement et articles.
class ListeCourses {
  const ListeCourses({required this.avancement, required this.articles});

  factory ListeCourses.depuisJson(Map<String, dynamic> json) => ListeCourses(
    avancement: AvancementCourses.depuisJson(
      json['progress'] as Map<String, dynamic>? ?? const {},
    ),
    articles: [
      for (final article in json['items'] as List<dynamic>? ?? const [])
        ArticleCourse.depuisJson(article as Map<String, dynamic>),
    ],
  );

  final AvancementCourses avancement;
  final List<ArticleCourse> articles;

  /// Articles regroupés par catégorie, dans l'ordre de l'énumération.
  ///
  /// Le regroupement est fait ici plutôt que dans l'écran : c'est une règle
  /// d'organisation de la liste, pas une question de présentation, et deux écrans
  /// finiraient par la dupliquer différemment.
  Map<CategorieCourse, List<ArticleCourse>> get parCategorie {
    final groupes = <CategorieCourse, List<ArticleCourse>>{};

    for (final categorie in CategorieCourse.values) {
      final articlesDeLaCategorie = articles
          .where((article) => article.categorie == categorie)
          .toList();

      if (articlesDeLaCategorie.isNotEmpty) {
        groupes[categorie] = articlesDeLaCategorie;
      }
    }

    return groupes;
  }
}
