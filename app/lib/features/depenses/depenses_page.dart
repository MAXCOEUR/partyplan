import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/models/depense.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_money.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'depense_feuille.dart';

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
          const SizedBox(height: PpSpacing.sm),
          // « Combien ça coûte » et « qui rend quoi » sont deux questions qui se
          // suivent : enterrer la seconde sous un menu obligerait à la chercher.
          _AccesReglements(evenementId: evenementId),
          const SizedBox(height: PpSpacing.lg),
          for (final depense in depenses) ...[
            _CarteDepense(evenementId: evenementId, depense: depense),
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
          Container(width: 1, height: 44, color: theme.colorScheme.outline),
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
class _CarteDepense extends ConsumerWidget {
  const _CarteDepense({required this.evenementId, required this.depense});

  static final _jour = DateFormat('d MMM', 'fr_FR');

  final String evenementId;
  final Depense depense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moi = ref.watch(monMembreProvider(evenementId)).value;

    // Le geste n'est proposé qu'à qui peut l'accomplir. Corriger la dépense d'autrui
    // change ce qu'il a avancé, donc ce que chacun lui doit ; le proposer pour le voir
    // refuser vaudrait moins que ne rien proposer.
    final laMienne = moi != null && depense.payeurMembreId == moi.id;
    final jePeuxAgir = laMienne || (moi?.role.peutGerer ?? false);

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
          if (jePeuxAgir)
            _MenuDepense(evenementId: evenementId, depense: depense),
        ],
      ),
    );
  }
}

/// Actions d'une dépense : corriger le montant, ou la retirer.
class _MenuDepense extends ConsumerWidget {
  const _MenuDepense({required this.evenementId, required this.depense});

  final String evenementId;
  final Depense depense;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    key: Key('menu-depense-${depense.id}'),
    icon: const Icon(Icons.more_vert_rounded, size: 18),
    onSelected: (choix) => _agir(context, ref, choix),
    itemBuilder: (_) => [
      // Une dépense née d'un achat de courses ne se modifie pas ici : son montant est
      // le prix payé sur la liste, et le corriger ailleurs créerait deux vérités.
      if (depense.issueDesCourses)
        const PopupMenuItem(
          value: 'courses',
          child: Text('Se corrige sur la liste de courses'),
        )
      else ...[
        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
      ],
    ],
  );

  Future<void> _agir(BuildContext context, WidgetRef ref, String choix) async {
    switch (choix) {
      case 'modifier':
        await ouvrirFeuilleDepense(context, evenementId, depense: depense);

      case 'supprimer':
        await _supprimer(context, ref);

      case 'courses':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Corrige le prix payé sur l’article, dans la liste de courses.',
            ),
          ),
        );
    }
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text('Supprimer « ${depense.libelle} » ?'),
        content: const Text(
          'Les soldes de chacun seront recalculés en conséquence.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Supprimer la dépense'),
          ),
        ],
      ),
    );

    if (confirme != true) {
      return;
    }

    try {
      await ref.read(depensesApiProvider).supprimer(evenementId, depense.id);
    } on ApiException catch (erreur) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suppression impossible pour le moment.'),
          ),
        );
      }
    } finally {
      ref
        ..invalidate(depensesProvider(evenementId))
        ..invalidate(reglementsProvider(evenementId));
    }
  }
}

class _Origine extends StatelessWidget {
  const _Origine({required this.issueDesCourses});

  final bool issueDesCourses;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    // Aucune couleur d'accent ici, et c'est un choix. L'origine d'une dépense est une
    // précision, pas un état : la teinter mettait un accent par ligne, et une soirée
    // dont toutes les dépenses viennent des courses affichait une liste entière en
    // rose — couleur que la charte réserve à l'argent dû. Les deux glyphes suffisent à
    // distinguer, et l'étiquette d'accessibilité dit le reste.
    return Semantics(
      label: issueDesCourses
          ? 'Issue de la liste de courses'
          : 'Saisie à la main',
      excludeSemantics: true,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: schema.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PpRadius.sm),
        ),
        child: Icon(
          issueDesCourses
              ? Icons.shopping_cart_rounded
              : Icons.receipt_long_rounded,
          size: 18,
          color: schema.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Passage vers les remboursements.
class _AccesReglements extends StatelessWidget {
  const _AccesReglements({required this.evenementId});

  final String evenementId;

  @override
  Widget build(BuildContext context) => PpCard(
    onTap: () => context.push(PpRoutes.versReglements(evenementId)),
    padding: const EdgeInsets.symmetric(
      horizontal: PpSpacing.lg,
      vertical: PpSpacing.md,
    ),
    child: Row(
      children: [
        const Icon(Icons.handshake_rounded, color: PpColors.violet),
        const SizedBox(width: PpSpacing.md),
        Expanded(
          child: Text(
            'Qui rend quoi',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
