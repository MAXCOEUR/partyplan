/// Une notification reçue (`§5.12`).
///
/// Nommée « avis » et non « notification » dans le code de l'application : le mot
/// « notification » y désigne déjà les notifications système de Flutter, et confondre
/// les deux rend chaque fichier ambigu.
class Avis {
  const Avis({
    required this.id,
    required this.categorie,
    required this.titre,
    required this.corps,
    required this.recuLe,
    required this.lu,
    this.evenementId,
    this.lienProfond,
  });

  factory Avis.depuisJson(Map<String, dynamic> json) => Avis(
    id: json['id'] as String,
    evenementId: json['eventId'] as String?,
    categorie: json['category'] as String? ?? '',
    titre: json['title'] as String? ?? '',
    corps: json['body'] as String? ?? '',
    lienProfond: json['deepLink'] as String?,
    recuLe: DateTime.parse(json['sentAt'] as String).toLocal(),
    lu: json['lue'] as bool? ?? false,
  );

  final String id;
  final String? evenementId;
  final String categorie;
  final String titre;
  final String corps;

  /// Route applicative ouverte au tap. Nulle quand l'avis ne mène nulle part.
  final String? lienProfond;

  final DateTime recuLe;
  final bool lu;

  Avis marqueLu() => Avis(
    id: id,
    evenementId: evenementId,
    categorie: categorie,
    titre: titre,
    corps: corps,
    lienProfond: lienProfond,
    recuLe: recuLe,
    lu: true,
  );
}

/// Une page d'avis, du plus récent au plus ancien.
class PageAvis {
  const PageAvis({
    required this.avis,
    required this.encore,
    required this.nonLus,
  });

  factory PageAvis.depuisJson(Map<String, dynamic> json) => PageAvis(
    avis: ((json['items'] as List<dynamic>?) ?? const [])
        .map((e) => Avis.depuisJson(e as Map<String, dynamic>))
        .toList(),
    encore: json['hasMore'] as bool? ?? false,
    nonLus: json['unreadCount'] as int? ?? 0,
  );

  static const vide = PageAvis(avis: [], encore: false, nonLus: 0);

  final List<Avis> avis;

  /// Reste-t-il des avis plus anciens à demander.
  final bool encore;

  /// Nombre total de non-lus, tous avis confondus — pas seulement sur cette page.
  /// C'est lui qui alimente la pastille.
  final int nonLus;
}

/// Préférence d'une catégorie (`EF-NOT-07`).
class PreferenceAvis {
  const PreferenceAvis({
    required this.categorie,
    required this.poussee,
    required this.courriel,
  });

  factory PreferenceAvis.depuisJson(Map<String, dynamic> json) =>
      PreferenceAvis(
        categorie: json['category'] as String? ?? '',
        poussee: json['pushEnabled'] as bool? ?? true,
        courriel: json['emailEnabled'] as bool? ?? true,
      );

  final String categorie;
  final bool poussee;
  final bool courriel;

  PreferenceAvis avec({bool? poussee}) => PreferenceAvis(
    categorie: categorie,
    poussee: poussee ?? this.poussee,
    courriel: courriel,
  );
}

/// Réglage résolu d'une catégorie pour une soirée donnée (`EF-NOT-09`).
///
/// [actif] porte la valeur déjà résolue côté serveur — écart de soirée, préférence
/// globale, valeur d'usine — et non le seul écart : l'écran ne doit pas rejouer cette
/// résolution de son côté, sous peine de diverger un jour de la règle serveur.
/// [estUnEcart] distingue une ligne posée pour cette soirée d'une valeur simplement
/// héritée. La sourdine n'entre pas dans [actif] : elle est exposée à part.
class PreferenceDeSoiree {
  const PreferenceDeSoiree({
    required this.categorie,
    required this.actif,
    required this.estUnEcart,
  });

  factory PreferenceDeSoiree.depuisJson(Map<String, dynamic> json) =>
      PreferenceDeSoiree(
        categorie: json['category'] as String? ?? '',
        actif: json['enabled'] as bool? ?? true,
        estUnEcart: json['estUnEcart'] as bool? ?? false,
      );

  final String categorie;
  final bool actif;
  final bool estUnEcart;
}
