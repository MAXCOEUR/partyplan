import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import 'tableau_de_bord_page.dart';

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
  Widget build(BuildContext context) {
    final onglets = _onglets(context);

    return Scaffold(
      appBar: AppBar(title: Text(onglets[_onglet].libelle)),
      // IndexedStack et non reconstruction : changer d'onglet ne doit ni recharger le
      // tableau de bord, ni perdre la position de défilement.
      body: IndexedStack(
        index: _onglet,
        children: [
          TableauDeBordPage(evenementId: widget.eventId),
          // Courses et Dépenses arrivent au sous-projet B2, Planning au B4.
          PpEmptyState(
            titre: onglets[1].libelle,
            explication: PpL10n.of(context).ongletBientot,
            icone: onglets[1].icoineActive,
          ),
          PpEmptyState(
            titre: onglets[2].libelle,
            explication: PpL10n.of(context).ongletBientot,
            icone: onglets[2].icoineActive,
          ),
          PpEmptyState(
            titre: onglets[3].libelle,
            explication: PpL10n.of(context).ongletBientot,
            icone: onglets[3].icoineActive,
          ),
          _MenuPlus(evenementId: widget.eventId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (index) => setState(() => _onglet = index),
        destinations: [
          for (final onglet in onglets)
            NavigationDestination(
              icon: Icon(onglet.icone),
              selectedIcon: Icon(onglet.icoineActive, color: PpColors.violet),
              label: onglet.libelle,
            ),
        ],
      ),
    );
  }
}

/// Entrées qui ne tiennent pas dans les cinq onglets (RG-UI-01).
class _MenuPlus extends StatelessWidget {
  const _MenuPlus({required this.evenementId});

  final String evenementId;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.people_outline_rounded),
          title: Text(l10n.menuPlusInvites),
          onTap: () => context.push(PpRoutes.versInvites(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share_rounded),
          title: Text(l10n.menuPlusInviter),
          onTap: () => context.push(PpRoutes.versInvitation(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.menuPlusParametres),
          onTap: () => context.push(PpRoutes.versParametres(evenementId)),
        ),
      ],
    );
  }
}
