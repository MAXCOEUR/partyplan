import 'dart:async';

import 'message_temps_reel.dart';
import 'service_temps_reel.dart';

/// Traduit un message diffusé en relecture.
///
/// Le client relit par REST plutôt que de rapiécer son état local. Rapiécer vingt-deux
/// messages dans autant de listes paginées, triées et filtrées créerait autant
/// d'occasions d'afficher autre chose que la base, sans qu'aucune erreur ne le signale.
/// `RG-RT-03` fait de REST la source de vérité, et invalider est impossible à
/// désynchroniser par construction.
///
/// Tout message provoque la même relecture, sans se servir du classement par famille de
/// [MessageTempsReel]. C'est volontaire : une soirée de vingt personnes produit peu de
/// messages, et un chemin unique est plus sûr que sept. Le classement existe et est
/// testé, il servira à affiner le jour où le volume le justifiera.
class EcouteEvenement {
  EcouteEvenement({required this.invalider});

  /// Relit ce que l'écran affiche. Passée en fonction pour que l'écoute reste testable
  /// sans conteneur de providers.
  final void Function() invalider;

  StreamSubscription<MessageTempsReel>? _messages;
  StreamSubscription<void>? _reconnexions;

  void demarrer(ServiceTempsReel service) {
    _messages = service.messages.listen((_) => invalider());

    // Une reconnexion impose un rechargement complet : ce qui a été manqué pendant la
    // coupure est par définition inconnu (RG-RT-03).
    _reconnexions = service.reconnexions.listen((_) => invalider());
  }

  /// Coupe les deux écoutes. Sans cet arrêt, quitter une soirée laisserait une écoute
  /// vivante invalidant les providers d'un écran disparu — une de plus à chaque soirée
  /// ouverte.
  Future<void> arreter() async {
    await _messages?.cancel();
    await _reconnexions?.cancel();
    _messages = null;
    _reconnexions = null;
  }
}
