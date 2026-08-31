import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet ouvert dans une soirée.
///
/// Nommé et non désigné par son rang : la règle d'affichage parle de « la discussion »,
/// pas de « l'onglet 3 », et un rang recopié se désynchronise le jour où l'ordre des
/// onglets change.
enum ZoneEvenement { accueil, courses, depenses, discussion, plus }

/// Onglet publié par la coquille, avec la soirée à laquelle il se rapporte.
typedef OngletPublie = ({String evenementId, ZoneEvenement onglet});

/// Ce que l'application montre à l'instant où une notification arrive.
///
/// Le chemin suffit pour tout ce qui est une adresse — l'accueil, les écrans poussés
/// d'une soirée, la liste des notifications. Il ne suffit pas pour les onglets d'une
/// soirée : la coquille les tient dans un `IndexedStack`, qui ne change pas d'adresse.
/// D'où le second champ, publié par la coquille elle-même.
class ZoneVisible {
  const ZoneVisible({required this.chemin, this.onglet});

  /// Compose la zone à partir du chemin courant et du dernier onglet publié.
  ///
  /// L'onglet n'est retenu que s'il porte sur la soirée effectivement affichée. Sans
  /// cette vérification, l'onglet de la soirée précédente resterait en vigueur le temps
  /// que la nouvelle coquille publie le sien, et masquerait à tort ses notifications.
  /// C'est aussi ce qui dispense la coquille d'effacer quoi que ce soit en se démontant,
  /// geste que Riverpod refuse pendant le démontage.
  factory ZoneVisible.composer({
    required String chemin,
    required OngletPublie? publie,
  }) {
    final zone = ZoneVisible(chemin: chemin);

    return publie != null && publie.evenementId == zone.evenementId
        ? ZoneVisible(chemin: chemin, onglet: publie.onglet)
        : zone;
  }

  /// Chemin courant du routeur, tel que `matchedLocation` le donne.
  final String chemin;

  /// Onglet ouvert, quand le chemin est celui d'une soirée.
  final ZoneEvenement? onglet;

  /// Soirée affichée, déduite du chemin, ou `null` si l'écran n'en montre aucune.
  String? get evenementId => _soiree.firstMatch(chemin)?.group(1);

  static final _soiree = RegExp(r'^/events/([^/]+)');
}

/// Onglet ouvert dans la soirée en cours, publié par la coquille.
class OngletEvenement extends Notifier<OngletPublie?> {
  @override
  OngletPublie? build() => null;

  void publier(String evenementId, ZoneEvenement onglet) =>
      state = (evenementId: evenementId, onglet: onglet);
}

final ongletEvenementProvider =
    NotifierProvider<OngletEvenement, OngletPublie?>(OngletEvenement.new);
