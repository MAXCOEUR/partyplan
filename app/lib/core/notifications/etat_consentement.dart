import '../storage/magasin_local.dart';
import 'service_notifications.dart';

/// Où en est le consentement aux notifications, une fois les sources croisées.
///
/// Fonction pure, isolée du service : c'est la décision qui a rendu la proposition
/// invisible sur Android pendant tout un lot, et elle doit pouvoir s'éprouver sans
/// téléphone.
abstract final class EtatConsentement {
  /// [autorise] vient du système. [dejaDemande] vient de l'application.
  ///
  /// Les deux sont nécessaires parce que le système ne répond pas à la question posée :
  /// sur Android, `getNotificationSettings` renvoie `denied` aussi bien pour un refus
  /// que pour une question jamais posée. Confondre les deux revient à ne jamais poser la
  /// question, puisque c'est la proposition elle-même qui ouvre la boîte système.
  static EtatNotifications resoudre({
    required bool firebaseDisponible,
    required bool autorise,
    required bool dejaDemande,
  }) {
    if (!firebaseDisponible) {
      return EtatNotifications.indisponible;
    }

    if (autorise) {
      // Le système fait foi : une installation restaurée peut porter la permission sans
      // que l'application se souvienne de l'avoir demandée.
      return EtatNotifications.accorde;
    }

    // Demandé, et toujours pas autorisé : c'est un refus. Reproposer donnerait un bouton
    // sans effet, Android ne représentant jamais la boîte système.
    return dejaDemande ? EtatNotifications.refuse : EtatNotifications.aDemander;
  }
}

/// Se souvient que la boîte système a déjà été présentée.
///
/// C'est la moitié de l'information que la plateforme ne donne pas.
class MemoireConsentement {
  const MemoireConsentement(this._magasin);

  static const _cle = 'notifications.demande_presentee';

  final MagasinLocal _magasin;

  /// En cas de panne du magasin, renvoie faux — donc repropose.
  ///
  /// Le sens de ce repli est réfléchi : une carte de trop se referme d'un geste, une
  /// carte manquante ne se découvre jamais. C'est exactement le défaut qui a masqué la
  /// proposition sur Android.
  Future<bool> dejaDemande() async {
    try {
      return await _magasin.lire(_cle) != null;
    } on Exception {
      return false;
    }
  }

  Future<void> marquerDemande() async {
    try {
      await _magasin.ecrire(_cle, 'oui');
    } on Exception {
      // Sans effet visible : la question sera reposée au prochain lancement, ce qui est
      // préférable à un échec remonté à l'écran pour une préférence d'affichage.
    }
  }
}
