/// Une ligne du fil d'activité (`EF-FIL-01`).
///
/// Le serveur envoie des **données**, jamais une phrase : la ligne est inaltérable en
/// base (`RG-FIL-02`), et une formulation stockée y resterait pour toujours. La phrase
/// est composée à l'affichage, depuis [categorie] et le payload.
class Activite {
  const Activite({
    required this.id,
    required this.auteur,
    required this.categorie,
    required this.creeLe,
    this.membreId,
    this.avatarUrl,
    this.donnees,
  });

  factory Activite.depuisJson(Map<String, dynamic> json) => Activite(
    id: json['id'] as String,
    membreId: json['memberId'] as String?,
    auteur: json['actorName'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    categorie: json['kind'] as String? ?? '',
    donnees: json['donnees'] as Map<String, dynamic>?,
    creeLe: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;

  final String? membreId;

  /// Nom figé à l'écriture : un changement de nom ne réécrit pas l'histoire
  /// (`RG-USR-04`).
  final String auteur;

  /// Photo actuelle de l'auteur, et non celle du jour de l'action : c'est ainsi qu'on
  /// reconnaît la personne aujourd'hui.
  final String? avatarUrl;

  final String categorie;

  final Map<String, dynamic>? donnees;

  final DateTime creeLe;

  /// Champ texte du payload, ou `null` s'il manque.
  ///
  /// Ne lève jamais : le fil est en ajout seul, et une ligne écrite par une version
  /// antérieure du serveur ne sera jamais corrigée. L'écran doit la traverser.
  String? texte(String cle) => donnees?[cle] as String?;

  /// Champ montant du payload.
  ///
  /// Lu en `num` avant conversion : un montant rond arrive en entier depuis JSON, et le
  /// lire directement en `double` masquerait la valeur.
  ///
  /// Affichage seul — le fil n'additionne rien, et ce nombre n'est jamais une source de
  /// calcul.
  double? montant(String cle) => (donnees?[cle] as num?)?.toDouble();

  /// Liste de chaînes du payload, pour `event.date_or_place_changed`.
  List<String> liste(String cle) =>
      (donnees?[cle] as List<dynamic>?)?.cast<String>() ?? const [];
}

/// Une page du fil, du plus récent au plus ancien.
class PageActivite {
  const PageActivite({required this.lignes, required this.encore});

  factory PageActivite.depuisJson(Map<String, dynamic> json) => PageActivite(
    lignes: ((json['items'] as List<dynamic>?) ?? const [])
        .map((e) => Activite.depuisJson(e as Map<String, dynamic>))
        .toList(),
    encore: json['hasMore'] as bool? ?? false,
  );

  static const vide = PageActivite(lignes: [], encore: false);

  final List<Activite> lignes;

  /// Reste-t-il des lignes plus anciennes à demander. Sans ce drapeau, l'application
  /// redemanderait indéfiniment une page qui n'existe pas.
  final bool encore;
}
