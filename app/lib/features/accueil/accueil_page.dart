import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/models/evenement.dart';
import '../../core/models/membre.dart';
import '../../core/providers.dart';
import '../../design/components/pp_bandeau_hors_ligne.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/components/pp_status_chip.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/marque.dart';
import '../evenement/presence_vers_pastille.dart';

/// Écran d'accueil : les événements de la personne, à venir puis passés (EF-EVT-05).
class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final evenements = ref.watch(mesEvenementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(PpMarque.nom),
        actions: [
          IconButton(
            onPressed: () => context.push(PpRoutes.profilEdition),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: l10n.accueilMonProfil,
          ),
          const SizedBox(width: PpSpacing.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(PpRoutes.creationEvenement),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.creerUnEvenement),
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: ref.watch(etatReseauProvider),
            builder: (context, _) => PpBandeauHorsLigne(
              etat: ref.read(etatReseauProvider),
              onReessayer: () => ref.invalidate(mesEvenementsProvider),
            ),
          ),
          Expanded(
            child: evenements.when(
              loading: () => const PpLoadingState(),
              error: (_, _) => PpErrorState(
                message: l10n.accueilChargementErreur,
                onRetry: () => ref.invalidate(mesEvenementsProvider),
              ),
              data: (liste) => liste.isEmpty
                  ? _etatVide(context)
                  : _Liste(evenements: liste, ref: ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etatVide(BuildContext context) {
    final l10n = PpL10n.of(context);

    return PpEmptyState(
      titre: l10n.accueilVideTitre,
      explication: l10n.accueilVideExplication,
      action: Column(
        children: [
          FilledButton.icon(
            onPressed: () => context.push(PpRoutes.creationEvenement),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.creerUnEvenement),
          ),
          const SizedBox(height: PpSpacing.sm),
          TextButton(
            onPressed: () => context.push(PpRoutes.rejoindreParCode),
            child: Text(l10n.rejoindreUnEvenement),
          ),
        ],
      ),
    );
  }
}

/// Liste sectionnée : à venir d'abord, du plus proche au plus lointain ; puis les
/// passés, du plus récent au plus ancien.
///
/// L'appartenance à une section vient du serveur (`isPast`) et n'est jamais recalculée :
/// l'horloge d'un téléphone peut être fausse, et une soirée passerait du mauvais côté.
class _Liste extends StatelessWidget {
  const _Liste({required this.evenements, required this.ref});

  final List<EvenementDeLaListe> evenements;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    final aVenir = evenements.where((e) => !e.estPasse).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    final passes = evenements.where((e) => e.estPasse).toList()
      ..sort((a, b) => b.debut.compareTo(a.debut));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mesEvenementsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PpSpacing.lg,
          PpSpacing.sm,
          PpSpacing.lg,
          PpSpacing.xxxl * 2,
        ),
        children: [
          if (aVenir.isNotEmpty) ...[
            PpEyebrow(l10n.evenementsAVenir),
            const SizedBox(height: PpSpacing.sm),
            for (final e in aVenir) _Carte(evenement: e),
          ],
          if (passes.isNotEmpty) ...[
            const SizedBox(height: PpSpacing.lg),
            PpEyebrow(l10n.evenementsPasses),
            const SizedBox(height: PpSpacing.sm),
            for (final e in passes) _Carte(evenement: e, estompee: true),
          ],
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.evenement, this.estompee = false});

  static final _dateFr = DateFormat('EEEE d MMMM, HH:mm', 'fr_FR');

  final EvenementDeLaListe evenement;
  final bool estompee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = PpL10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.md),
      child: Opacity(
        opacity: estompee ? 0.7 : 1,
        child: PpCard(
          onTap: () => context.push(PpRoutes.versEvenement(evenement.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (evenement.monRole.peutGerer)
                PpEyebrow(
                  evenement.monRole == RoleMembre.proprietaire
                      ? l10n.roleProprietaire
                      : l10n.roleAdministrateur,
                  couleur: PpColors.violet,
                ),
              // Le rôle est placé au-dessus du titre et non à côté : un nom long et une
              // étiquette « CO-ORGANISATEUR » ne tiennent pas sur une ligne de
              // téléphone, et tronquer le nom de l'événement serait le pire choix.
              Text(evenement.nom, style: theme.textTheme.titleLarge),
              const SizedBox(height: PpSpacing.xs),
              Text(
                [
                  _dateFr.format(evenement.debut),
                  ?evenement.adresse,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: PpSpacing.md),
              // Wrap et non Row : sur un téléphone étroit, « Arrive plus tard » suivi
              // de « 12 présents sur 24 invités » dépasse la largeur disponible.
              Wrap(
                spacing: PpSpacing.sm,
                runSpacing: PpSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PpStatusChip(presence: versPastille(evenement.monStatut)),
                  Text(
                    l10n.presencesSurInvites(
                      evenement.presents,
                      evenement.invites,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vitrine des composants du système de design.
///
/// Conservée dans l'application, et non dans un projet séparé : un système de design
/// que l'on ne peut pas voir tourner dérive silencieusement du produit.
class GalerieDesignPage extends StatelessWidget {
  const GalerieDesignPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Galerie des composants')));
}
