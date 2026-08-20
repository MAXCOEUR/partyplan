import 'package:flutter/material.dart';

import '../../design/components/pp_states.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Parcours de participation, en deux écrans au maximum : prénom, puis présence
/// (RG-INV-05).
///
/// Squelette au lot 0.5. Le parcours complet est le lot 1.3, et c'est le chemin le plus
/// critique du produit pour l'adoption : toute friction ajoutée ici se paie en taux de
/// réponse.
class RejoindrePage extends StatelessWidget {
  const RejoindrePage({this.token, super.key});

  /// Jeton du lien d'invitation. Nul lorsque l'écran est ouvert pour saisir un code court.
  final String? token;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(PpL10n.of(context).rejoindreUnEvenement)),
    body: PpEmptyState(
      titre: token == null ? 'Saisis le code de la soirée' : 'Invitation reçue',
      explication: token == null
          ? 'Le code figure sur l’invitation, sous la forme PLAN-XXXXXX.'
          : 'Le parcours de participation arrive au lot 1.3.',
      icone: Icons.qr_code_rounded,
    ),
  );
}
