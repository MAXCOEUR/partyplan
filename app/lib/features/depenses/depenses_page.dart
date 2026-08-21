import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/depense.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_money.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Dépenses d'un événement (`EF-DEP-04`).
///
/// Deux origines dans une seule liste : ce qui a été payé pendant les courses, et ce
/// qui n'a rien à voir avec elles — location de salle, taxi, matériel. Les séparer en
/// deux écrans obligerait à additionner de tête pour savoir ce que la soirée a coûté.
class DepensesPage extends ConsumerWidget {
  const DepensesPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(depensesProvider(evenementId));

    return page.when(
      loading: () => const PpLoadingState(),
      error: (_, _) => PpErrorState(
        message: 'Impossible de charger les dépenses.',
        onRetry: () => ref.invalidate(depensesProvider(evenementId)),
      ),
      data: (donnees) => _Liste(evenementId: evenementId, page: donnees),
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.evenementId, required this.page});

  final String evenementId;
  final PageDepenses page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.estVide) {
      return const PpEmptyState(
        titre: 'Aucune dépense pour l’instant',
        explication:
            'Les achats de la liste de courses arrivent ici tout seuls. '
            'Ajoute le reste à la main : location, taxi, matériel.',
        icone: Icons.receipt_long_rounded,
      );
    }

    // La plus récente d'abord : on consulte cette liste pour vérifier ce qui vient
    // d'être ajouté, pas pour relire l'historique depuis le début.
    final depenses = [...page.depenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(depensesProvider(evenementId)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PpSpacing.lg,
          PpSpacing.lg,
          PpSpacing.lg,
          PpSpacing.xxxl * 2,
        ),
        children: [
          _Totaux(total: page.total, maPart: page.maPart),
          const SizedBox(height: PpSpacing.lg),
          for (final depense in depenses) ...[
            _CarteDepense(depense: depense),
            const SizedBox(height: PpSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Ce que la soirée a coûté, et ce que l'appelant y pèse.
///
/// Les deux chiffres sont donnés côte à côte parce qu'ils répondent à deux questions
/// différentes, posées dans cet ordre : « combien pour la soirée » puis « combien pour
/// moi ». Sa part n'est pas ce qu'il doit : les remboursements tiennent compte de ce
/// qu'il a lui-même avancé.
class _Totaux extends StatelessWidget {
  const _Totaux({required this.total, required this.maPart});

  final double total;
  final double maPart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Row(
        children: [
          Expanded(
            child: _Chiffre(
              etiquette: 'TOTAL DE LA SOIRÉE',
              montant: total,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: theme.colorScheme.outline,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: PpSpacing.lg),
              child: _Chiffre(
                etiquette: 'MA PART',
                montant: maPart,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.etiquette,
    required this.montant,
    required this.style,
  });

  final String etiquette;
  final double montant;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiquette,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: PpSpacing.xs),
        PpMoney(montant, style: style),
      ],
    );
  }
}

/// Une dépense : ce qui a été payé, par qui, et pour combien de personnes.
class _CarteDepense extends StatelessWidget {
  const _CarteDepense({required this.depense});

  static final _jour = DateFormat('d MMM', 'fr_FR');

  final Depense depense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Row(
        children: [
          // Le repère d'origine : une dépense née d'un achat de courses n'a pas été
          // saisie par quiconque, et sans cette marque personne ne comprend d'où elle
          // sort.
          _Origine(issueDesCourses: depense.issueDesCourses),
          const SizedBox(width: PpSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  depense.libelle,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: PpSpacing.xs),
                Text(
                  'Payé par ${depense.payeurNom} · '
                  '${depense.nombreParticipants} '
                  '${depense.nombreParticipants > 1 ? 'participants' : 'participant'} · '
                  '${_jour.format(depense.date)}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: PpSpacing.sm),
          PpMoney(
            depense.montant,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: PpTypography.chiffresTabulaires,
            ),
          ),
        ],
      ),
    );
  }
}

class _Origine extends StatelessWidget {
  const _Origine({required this.issueDesCourses});

  final bool issueDesCourses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = issueDesCourses ? PpColors.rose : PpColors.violet;

    return Semantics(
      label: issueDesCourses ? 'Issue de la liste de courses' : 'Saisie à la main',
      excludeSemantics: true,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PpRadius.sm),
        ),
        child: Icon(
          issueDesCourses
              ? Icons.shopping_cart_rounded
              : Icons.receipt_long_rounded,
          size: 18,
          color: PpColors.texteSur(couleur, theme.brightness),
        ),
      ),
    );
  }
}
