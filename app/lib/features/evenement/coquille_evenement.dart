import 'package:flutter/material.dart';

import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Coquille de navigation d'un événement.
///
/// Cinq entrées, jamais plus (RG-UI-01) : tout ce qui vient ensuite — invités, tâches,
/// sondages, discussion, paramètres — passe sous « Plus ». La contrainte est posée dès
/// maintenant, car c'est en ajoutant un sixième onglet « juste pour cette fois » que la
/// navigation se dégrade.
class CoquilleEvenement extends StatefulWidget {
  const CoquilleEvenement({required this.eventId, super.key});

  final String eventId;

  @override
  State<CoquilleEvenement> createState() => _CoquilleEvenementState();
}

class _CoquilleEvenementState extends State<CoquilleEvenement> {
  int _onglet = 0;

  /// Onglets de la navigation d'événement (RG-UI-01).
  ///
  /// Construits à la demande et non dans une constante : les libellés sont traduits,
  /// donc dépendants du contexte.
  static List<({String libelle, IconData icone, IconData icoineActive})>
  _onglets(BuildContext context) {
    final l10n = PpL10n.of(context);

    return [
      (
        libelle: l10n.ongletAccueil,
        icone: Icons.home_outlined,
        icoineActive: Icons.home_rounded,
      ),
      (
        libelle: l10n.ongletCourses,
        icone: Icons.shopping_cart_outlined,
        icoineActive: Icons.shopping_cart_rounded,
      ),
      (
        libelle: l10n.ongletDepenses,
        icone: Icons.euro_rounded,
        icoineActive: Icons.euro_rounded,
      ),
      (
        libelle: l10n.ongletPlanning,
        icone: Icons.event_outlined,
        icoineActive: Icons.event_rounded,
      ),
      (
        libelle: l10n.ongletPlus,
        icone: Icons.more_horiz_rounded,
        icoineActive: Icons.more_horiz_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_onglets(context)[_onglet].libelle)),
    body: PpEmptyState(
      titre: _onglets(context)[_onglet].libelle,
      explication:
          'Cet écran est branché en V1.0. Événement ${widget.eventId}.',
      icone: _onglets(context)[_onglet].icoineActive,
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _onglet,
      onDestinationSelected: (index) => setState(() => _onglet = index),
      destinations: [
        for (final onglet in _onglets(context))
          NavigationDestination(
            icon: Icon(onglet.icone),
            selectedIcon: Icon(onglet.icoineActive, color: PpColors.violet),
            label: onglet.libelle,
          ),
      ],
    ),
  );
}
