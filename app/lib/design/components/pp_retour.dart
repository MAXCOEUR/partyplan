import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bouton de retour qui ne laisse jamais l'utilisateur ailleurs qu'attendu.
///
/// Le bouton de retour ordinaire dépile la navigation. Il ne peut rien faire quand il
/// n'y a rien à dépiler : après un rechargement de page, ou en arrivant par un lien
/// direct, l'écran n'a pas de parent dans la pile. L'utilisateur restait alors sur
/// place, ou se retrouvait renvoyé à la liste des soirées.
///
/// Ici, faute de pile, on remonte à l'adresse parente déclarée — celle qui contient
/// logiquement l'écran courant.
class PpRetour extends StatelessWidget {
  const PpRetour({required this.versParent, super.key});

  /// Adresse à rejoindre quand il n'y a rien à dépiler.
  final String versParent;

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      final navigateur = Navigator.of(context);

      if (navigateur.canPop()) {
        navigateur.pop();
        return;
      }

      // `go` et non `push` : empiler le parent au-dessus de l'écran quitté ferait
      // grandir la pile à chaque retour.
      context.go(versParent);
    },
  );
}
