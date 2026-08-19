import 'package:flutter/material.dart';

/// Exécute une écriture en mode optimiste : l'interface reflète le résultat attendu
/// immédiatement, et revient en arrière avec un message explicite si le serveur refuse
/// (RG-UI-03).
///
/// Centralisé ici plutôt que réécrit à chaque appel : un retour arrière silencieux
/// laisserait l'utilisateur croire que son action a été enregistrée, ce qui est
/// inacceptable sur une liste de courses partagée ou une dépense.
class PpOptimisticAction {
  const PpOptimisticAction._();

  static Future<bool> executer({
    required BuildContext context,
    required VoidCallback appliquer,
    required VoidCallback annuler,
    required Future<void> Function() envoyer,
    required String messageEchec,
  }) async {
    appliquer();

    try {
      await envoyer();
      return true;
    } on Exception {
      annuler();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageEchec)));
      }

      return false;
    }
  }
}
