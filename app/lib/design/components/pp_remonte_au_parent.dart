import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Fait remonter à l'écran parent quand il n'y a rien à dépiler.
///
/// Trois gestes demandent la même chose et empruntent trois chemins différents : le
/// bouton affiché dans la barre, le bouton matériel d'Android, et le « précédent » du
/// navigateur. Les deux derniers ne passent pas par la barre — ils demandent un pop au
/// routeur.
///
/// Sans pile à dépiler — page rechargée, lien ouvert directement — ce pop ne mène nulle
/// part : l'application se refermait sur Android, et le navigateur quittait vers la page
/// d'entrée en faisant perdre l'événement où l'on se trouvait. Ce widget intercepte le
/// geste et rejoint l'adresse parente.
///
/// À placer autour du contenu d'un écran atteint depuis un autre, jamais à la racine :
/// à l'accueil, le retour système doit bien fermer l'application.
class PpRemonteAuParent extends StatelessWidget {
  const PpRemonteAuParent({
    required this.versParent,
    required this.child,
    super.key,
  });

  /// Adresse à rejoindre faute de pile.
  final String versParent;

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    // Laisser passer le pop quand il y a de quoi dépiler : la navigation ordinaire
    // doit rester la navigation ordinaire.
    canPop: Navigator.of(context).canPop(),
    onPopInvokedWithResult: (aDepile, _) {
      if (!aDepile && context.mounted) {
        context.go(versParent);
      }
    },
    child: child,
  );
}
