/// Réponse possible d'un sondage, avec son décompte.
class OptionSondage {
  const OptionSondage({
    required this.id,
    required this.libelle,
    required this.voix,
    required this.laMienne,
  });

  factory OptionSondage.depuisJson(Map<String, dynamic> json) => OptionSondage(
    id: json['id'] as String,
    libelle: json['label'] as String? ?? '',
    voix: json['votes'] as int? ?? 0,
    laMienne: json['mine'] as bool? ?? false,
  );

  final String id;
  final String libelle;
  final int voix;

  /// Vrai lorsque l'appelant a choisi cette réponse.
  final bool laMienne;
}

/// Sondage d'un événement.
class Sondage {
  const Sondage({
    required this.id,
    required this.question,
    required this.choixMultiple,
    required this.clos,
    required this.jAiVote,
    required this.votants,
    required this.auteur,
    required this.creeLe,
    required this.options,
  });

  factory Sondage.depuisJson(Map<String, dynamic> json) => Sondage(
    id: json['id'] as String,
    question: json['question'] as String? ?? '',
    choixMultiple: json['allowMultiple'] as bool? ?? false,
    clos: json['closed'] as bool? ?? false,
    jAiVote: json['iVoted'] as bool? ?? false,
    votants: json['voters'] as int? ?? 0,
    auteur: json['createdByDisplayName'] as String? ?? '',
    creeLe: DateTime.parse(json['createdAt'] as String),
    options: [
      for (final o in json['options'] as List<dynamic>? ?? const [])
        OptionSondage.depuisJson(o as Map<String, dynamic>),
    ],
  );

  final String id;
  final String question;

  /// Vrai lorsque plusieurs réponses peuvent être cochées — « qui apporte quoi ».
  final bool choixMultiple;

  final bool clos;
  final bool jAiVote;

  /// Nombre de personnes ayant voté, et non nombre de voix : quelqu'un qui coche deux
  /// réponses ne compte qu'une fois.
  final int votants;

  final String auteur;
  final DateTime creeLe;
  final List<OptionSondage> options;

  /// Total des voix, pour dessiner les proportions.
  int get totalVoix => options.fold(0, (total, o) => total + o.voix);

  /// Part d'une réponse, entre 0 et 1. Nulle tant que personne n'a voté : une barre
  /// pleine sur un sondage vierge laisserait croire à un résultat.
  double part(OptionSondage option) =>
      totalVoix == 0 ? 0 : option.voix / totalVoix;
}

/// Sondages d'un événement, les ouverts d'abord.
class PageSondages {
  const PageSondages({required this.sondages});

  factory PageSondages.depuisJson(Map<String, dynamic> json) => PageSondages(
    sondages: [
      for (final s in json['items'] as List<dynamic>? ?? const [])
        Sondage.depuisJson(s as Map<String, dynamic>),
    ],
  );

  final List<Sondage> sondages;

  bool get estVide => sondages.isEmpty;

  List<Sondage> get ouverts => [
    for (final sondage in sondages)
      if (!sondage.clos) sondage,
  ];
}
