import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/sondage.dart';
import '../../core/network/api_exception.dart';
import '../../app/router.dart';
import '../../core/providers.dart';
import '../../design/components/pp_barre_evenement.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_remonte_au_parent.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import 'sondage_feuille.dart';

/// Sondages d'un événement (`EF-SDG-01` à `EF-SDG-04`).
///
/// Ils naissent dans la discussion, mais un sondage remonté par cinquante messages
/// devient introuvable : cet écran les rassemble, les ouverts d'abord — on vient ici
/// pour répondre, pas pour relire ce qui est tranché.
class SondagesPage extends ConsumerWidget {
  const SondagesPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sondages = ref.watch(sondagesProvider(evenementId));

    return PpRemonteAuParent(
      versParent: PpRoutes.versEvenement(evenementId),
      child: Scaffold(
        appBar: PpBarreEvenement(evenementId: evenementId, section: 'SONDAGES'),
        floatingActionButtonLocation: const PpFabDansLeRail(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => ouvrirFeuilleSondage(context, evenementId),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Sondage'),
        ),
        body: PpRail(
          child: sondages.when(
            loading: () => const PpLoadingState(),
            error: (_, _) => PpErrorState(
              message: 'Impossible de charger les sondages.',
              onRetry: () => ref.invalidate(sondagesProvider(evenementId)),
            ),
            data: (page) => page.estVide
                ? const PpEmptyState(
                    titre: 'Aucun sondage',
                    explication:
                        'Pose une question à choix multiples : ce qu’on commande, '
                        'qui apporte quoi. Le sondage apparaît dans la discussion '
                        'et se retrouve ici.',
                    icone: Icons.how_to_vote_rounded,
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(sondagesProvider(evenementId)),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        PpSpacing.lg,
                        PpSpacing.lg,
                        PpSpacing.lg,
                        PpSpacing.xxxl * 2,
                      ),
                      children: [
                        for (final sondage in page.sondages) ...[
                          CarteSondage(
                            evenementId: evenementId,
                            sondage: sondage,
                          ),
                          const SizedBox(height: PpSpacing.md),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Un sondage : sa question, ses réponses, et le vote.
///
/// Employée aussi dans le fil de discussion, sous le message qui l'annonce : répondre
/// sans quitter la conversation est le geste attendu.
class CarteSondage extends ConsumerStatefulWidget {
  const CarteSondage({
    required this.evenementId,
    required this.sondage,
    super.key,
  });

  final String evenementId;
  final Sondage sondage;

  @override
  ConsumerState<CarteSondage> createState() => _CarteSondageState();
}

class _CarteSondageState extends ConsumerState<CarteSondage> {
  bool _enCours = false;

  Sondage get _sondage => widget.sondage;

  /// Enregistre le choix d'une réponse.
  ///
  /// En choix unique, la réponse remplace la précédente. En choix multiple, elle
  /// s'ajoute ou se retire sans toucher aux autres — cocher « dessert » ne doit pas
  /// effacer « entrée ».
  Future<void> _choisir(OptionSondage option) async {
    if (_sondage.clos || _enCours) {
      return;
    }

    final choix = <String>[];

    if (_sondage.choixMultiple) {
      choix.addAll(_sondage.options.where((o) => o.laMienne).map((o) => o.id));

      if (choix.contains(option.id)) {
        choix.remove(option.id);
      } else {
        choix.add(option.id);
      }
    } else if (!option.laMienne) {
      choix.add(option.id);
    }

    setState(() => _enCours = true);

    try {
      await ref
          .read(sondagesApiProvider)
          .voter(widget.evenementId, _sondage.id, optionIds: choix);
    } on ApiException catch (erreur) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote impossible pour le moment.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }

      ref
        ..invalidate(sondagesProvider(widget.evenementId))
        ..invalidate(filDiscussionProvider(widget.evenementId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sondage = _sondage;

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sondage.question,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (sondage.clos)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PpSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(PpRadius.pill),
                  ),
                  child: Text('Clos', style: theme.textTheme.labelSmall),
                ),
            ],
          ),
          const SizedBox(height: PpSpacing.xs),
          Text(
            [
              sondage.choixMultiple
                  ? 'Plusieurs réponses possibles'
                  : 'Une seule réponse',
              sondage.votants == 0
                  ? 'personne n’a encore voté'
                  : sondage.votants == 1
                  ? '1 personne a voté'
                  : '${sondage.votants} personnes ont voté',
            ].join(' · '),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: PpSpacing.md),
          for (final option in sondage.options) ...[
            _Reponse(
              sondage: sondage,
              option: option,
              enCours: _enCours,
              onChoisir: () => _choisir(option),
            ),
            const SizedBox(height: PpSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Une réponse : son libellé, sa part, et son décompte.
///
/// La barre de proportion est dessinée en fond du libellé plutôt qu'à côté : le
/// résultat se lit alors sans passer d'une colonne à l'autre.
class _Reponse extends StatelessWidget {
  const _Reponse({
    required this.sondage,
    required this.option,
    required this.enCours,
    required this.onChoisir,
  });

  final Sondage sondage;
  final OptionSondage option;
  final bool enCours;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = sondage.part(option);

    return InkWell(
      onTap: sondage.clos || enCours ? null : onChoisir,
      borderRadius: BorderRadius.circular(PpRadius.md),
      child: Stack(
        children: [
          // Le fond proportionnel, sous le contenu.
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: part,
              child: AnimatedContainer(
                duration: PpDuration.normale,
                decoration: BoxDecoration(
                  color: option.laMienne
                      ? PpColors.violet.withValues(alpha: 0.22)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(PpRadius.md),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PpSpacing.md,
              vertical: PpSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(PpRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  option.laMienne
                      ? (sondage.choixMultiple
                            ? Icons.check_box_rounded
                            : Icons.radio_button_checked_rounded)
                      : (sondage.choixMultiple
                            ? Icons.check_box_outline_blank_rounded
                            : Icons.radio_button_unchecked_rounded),
                  size: 18,
                  color: option.laMienne ? PpColors.violet : null,
                ),
                const SizedBox(width: PpSpacing.sm),
                Expanded(
                  child: Text(
                    option.libelle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: option.laMienne ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                Text('${option.voix}', style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
