import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

import '../../app/router.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../courses/article_feuille.dart';
import '../courses/courses_page.dart';
import 'tableau_de_bord_page.dart';

/// Coquille de navigation d'un événement.
///
/// Cinq entrées, jamais plus (RG-UI-01) : tout ce qui vient ensuite — invités, tâches,
/// sondages, discussion, paramètres — passe sous « Plus ». La contrainte est posée dès
/// maintenant, car c'est en ajoutant un sixième onglet « juste pour cette fois » que la
/// navigation se dégrade.
class CoquilleEvenement extends ConsumerStatefulWidget {
  const CoquilleEvenement({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<CoquilleEvenement> createState() => _CoquilleEvenementState();
}

class _CoquilleEvenementState extends ConsumerState<CoquilleEvenement> {
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
    final evenement = ref.watch(evenementProvider(widget.eventId)).value;

    // Au-delà de ce seuil, une barre de navigation basse étalée sur toute la largeur
    // sépare le geste du regard : la place est alors sur le côté.
    final large =
        MediaQuery.sizeOf(context).width >= PpBreakpoints.large;

    return Scaffold(
      appBar: PpBarreApp(
        bouton: const BackButton(),
        // Le nom de l'événement, pas celui de l'onglet : « Courses » ne dit pas de
        // quelle soirée il s'agit, et l'on peut être membre de trois événements.
        titre: Text(evenement?.nom ?? onglets[_onglet].libelle),
        basDeBarre: evenement == null
            ? null
            : _SousTitreEvenement(
                onglet: onglets[_onglet].libelle,
                membres: evenement.nombreMembres,
                presents: evenement.nombrePresents,
              ),
      ),
      // IndexedStack et non reconstruction : changer d'onglet ne doit ni recharger le
      // tableau de bord, ni perdre la position de défilement.
      body: _Corps(
        large: large,
        onglets: onglets,
        selection: _onglet,
        onSelection: (index) => setState(() => _onglet = index),
        child: IndexedStack(
        index: _onglet,
        children: [
          TableauDeBordPage(evenementId: widget.eventId),
          CoursesPage(evenementId: widget.eventId),
          // Dépenses et Planning arrivent aux sous-projets suivants.
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
      ),
      floatingActionButtonLocation: const PpFabDansLeRail(),
      floatingActionButton: _onglet == 1
          ? FloatingActionButton.extended(
              onPressed: () => ouvrirFeuilleArticle(context, widget.eventId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            )
          : null,
      bottomNavigationBar: large
          ? null
          : NavigationBar(
              selectedIndex: _onglet,
              onDestinationSelected: (index) => setState(() => _onglet = index),
              destinations: [
                for (final onglet in onglets)
                  NavigationDestination(
                    icon: Icon(onglet.icone),
                    selectedIcon: Icon(
                      onglet.icoineActive,
                      color: PpColors.violet,
                    ),
                    label: onglet.libelle,
                  ),
              ],
            ),
    );
  }
}

/// Deuxième ligne de la barre : l'onglet ouvert et l'état des présences.
///
/// Le titre porte le nom de l'événement, cette ligne dit où l'on est et combien de
/// monde est attendu. Deux informations que l'on cherche sans arrêt en préparant une
/// soirée, et qui n'ont pas à coûter une navigation.
class _SousTitreEvenement extends StatelessWidget implements PreferredSizeWidget {
  const _SousTitreEvenement({
    required this.onglet,
    required this.membres,
    required this.presents,
  });

  final String onglet;
  final int membres;
  final int presents;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: PpSpacing.lg,
        right: PpSpacing.lg,
        bottom: PpSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            onglet.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: PpColors.violet,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: PpSpacing.sm),
          Text('·', style: theme.textTheme.labelSmall),
          const SizedBox(width: PpSpacing.sm),
          Text(
            '$presents présents sur $membres',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Dispose la navigation : sur le côté quand la place le permet, en bas sinon.
///
/// Le contenu est posé dans un rail, faute de quoi une carte s'étirerait sur toute la
/// largeur d'un écran de bureau et son bouton d'action se retrouverait à l'autre bout.
class _Corps extends StatelessWidget {
  const _Corps({
    required this.large,
    required this.onglets,
    required this.selection,
    required this.onSelection,
    required this.child,
  });

  final bool large;
  final List<({String libelle, IconData icone, IconData icoineActive})> onglets;
  final int selection;
  final ValueChanged<int> onSelection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contenu = PpRail(child: child);

    if (!large) {
      return contenu;
    }

    return Row(
      children: [
        NavigationRail(
          selectedIndex: selection,
          onDestinationSelected: onSelection,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final onglet in onglets)
              NavigationRailDestination(
                icon: Icon(onglet.icone),
                selectedIcon: Icon(onglet.icoineActive, color: PpColors.violet),
                label: Text(onglet.libelle),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: contenu),
      ],
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
