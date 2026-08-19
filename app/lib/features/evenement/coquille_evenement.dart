import 'package:flutter/material.dart';

import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';

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

  static const _onglets =
      <({String libelle, IconData icone, IconData icoineActive})>[
        (
          libelle: PpStrings.ongletAccueil,
          icone: Icons.home_outlined,
          icoineActive: Icons.home_rounded,
        ),
        (
          libelle: PpStrings.ongletCourses,
          icone: Icons.shopping_cart_outlined,
          icoineActive: Icons.shopping_cart_rounded,
        ),
        (
          libelle: PpStrings.ongletDepenses,
          icone: Icons.euro_rounded,
          icoineActive: Icons.euro_rounded,
        ),
        (
          libelle: PpStrings.ongletPlanning,
          icone: Icons.event_outlined,
          icoineActive: Icons.event_rounded,
        ),
        (
          libelle: PpStrings.ongletPlus,
          icone: Icons.more_horiz_rounded,
          icoineActive: Icons.more_horiz_rounded,
        ),
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_onglets[_onglet].libelle)),
    body: PpEmptyState(
      titre: _onglets[_onglet].libelle,
      explication:
          'Cet écran est branché en V1.0. Événement ${widget.eventId}.',
      icone: _onglets[_onglet].icoineActive,
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _onglet,
      onDestinationSelected: (index) => setState(() => _onglet = index),
      destinations: [
        for (final onglet in _onglets)
          NavigationDestination(
            icon: Icon(onglet.icone),
            selectedIcon: Icon(onglet.icoineActive, color: PpColors.violet),
            label: onglet.libelle,
          ),
      ],
    ),
  );
}
