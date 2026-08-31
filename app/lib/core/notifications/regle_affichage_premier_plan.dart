import 'notification_recue.dart';
import 'zone_visible.dart';

/// Faut-il annoncer cette notification, alors que l'application est déjà ouverte ?
///
/// Fonction pure, sans Flutter ni Firebase : c'est la pièce qui porte la valeur de ce
/// lot, donc celle qui doit s'éprouver sans monter une application.
///
/// Le principe tient en une phrase : **on masque uniquement ce que l'écran ouvert montre
/// déjà, et seulement pour la soirée qu'il montre**. Tout le reste s'affiche.
abstract final class RegleAffichagePremierPlan {
  /// Catégories déjà visibles, par écran.
  ///
  /// `poll.new` figure deux fois, et ce n'est pas une redite : un sondage créé paraît
  /// dans le fil de discussion autant que dans l'écran des sondages.
  static const _masqueesParOnglet = <ZoneEvenement, Set<String>>{
    ZoneEvenement.discussion: {
      'discussion.message',
      'discussion.mention',
      'poll.new',
    },
    ZoneEvenement.depenses: {'expense.new'},
    ZoneEvenement.courses: {'shopping.unclaimed'},
  };

  /// Mêmes correspondances, pour les écrans d'une soirée qui sont des adresses à part
  /// entière.
  static const _masqueesParChemin = <String, Set<String>>{
    'sondages': {'poll.new'},
    'activite': {'activity'},
  };

  static bool doitAfficher(NotificationRecue recue, ZoneVisible zone) {
    // La liste des notifications les contient toutes, de toutes les soirées : annoncer
    // par-dessus ce qu'on est venu lire n'apporte rien.
    if (zone.chemin == '/notifications') {
      return false;
    }

    final categorie = recue.categorie;

    // Sans catégorie, rien ne permet d'affirmer que l'écran la montre déjà. Le défaut
    // de cette table est de ne rien masquer : sinon une catégorie ajoutée demain naîtrait
    // muette, et personne ne s'en apercevrait.
    if (categorie == null) {
      return true;
    }

    // Une notification d'une autre soirée s'affiche toujours. Être dans la discussion
    // de la crémaillère ne doit rien masquer du week-end à la montagne.
    final soireeAffichee = zone.evenementId;
    if (soireeAffichee == null ||
        recue.evenementId == null ||
        recue.evenementId != soireeAffichee) {
      return true;
    }

    return !_masquee(categorie, zone);
  }

  static bool _masquee(String categorie, ZoneVisible zone) {
    final segments = zone.chemin.split('/');

    // `/events/{id}/{ecran}` : quatre segments, le premier étant vide.
    if (segments.length > 3) {
      return _masqueesParChemin[segments[3]]?.contains(categorie) ?? false;
    }

    final onglet = zone.onglet;
    return onglet != null &&
        (_masqueesParOnglet[onglet]?.contains(categorie) ?? false);
  }
}
