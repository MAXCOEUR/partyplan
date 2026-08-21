import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/reglement.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_barre_evenement.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_money.dart';
import '../../app/router.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_remonte_au_parent.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';

/// Remboursements d'un événement (`EF-RMB-01` à `EF-RMB-05`).
///
/// L'écran répond à une seule question, dans cet ordre : « qu'est-ce que je dois, et à
/// qui ». Le reste — soldes de chacun, règlements déjà faits — vient après.
///
/// Aucun calcul n'est fait ici. Les soldes et les règlements proposés viennent du
/// serveur, recalculés à la demande (`RG-RMB-02`), et l'ordre reçu est conservé
/// (`RG-CALC-01`) : retrier ferait voir deux ordres différents à deux personnes.
class ReglementsPage extends ConsumerWidget {
  const ReglementsPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(reglementsProvider(evenementId));

    return page.when(
      loading: () => const PpLoadingState(),
      error: (_, _) => PpErrorState(
        message: 'Impossible de calculer les remboursements.',
        onRetry: () => ref.invalidate(reglementsProvider(evenementId)),
      ),
      data: (donnees) => _Contenu(evenementId: evenementId, page: donnees),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.evenementId, required this.page});

  final String evenementId;
  final PageReglements page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reglementsProvider(evenementId)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PpSpacing.lg,
          PpSpacing.lg,
          PpSpacing.lg,
          PpSpacing.xxxl * 2,
        ),
        children: [
          if (!page.invariantRespecte) ...[
            const _Avertissement(),
            const SizedBox(height: PpSpacing.lg),
          ],
          _MonSolde(montant: page.monSolde),
          const SizedBox(height: PpSpacing.lg),
          if (page.rienARegler)
            const PpEmptyState(
              titre: 'Rien à rembourser',
              explication:
                  'Dès qu’une dépense sera partagée, les remboursements à faire '
                  'apparaîtront ici, réduits au minimum de virements.',
              icone: Icons.handshake_rounded,
            ),
          if (page.proposes.isNotEmpty) ...[
            const _Titre('À rembourser'),
            for (final reglement in page.proposes) ...[
              _CarteReglement(evenementId: evenementId, reglement: reglement),
              const SizedBox(height: PpSpacing.sm),
            ],
            const SizedBox(height: PpSpacing.lg),
          ],
          if (page.effectues.isNotEmpty) ...[
            const _Titre('Déjà réglé'),
            for (final reglement in page.effectues) ...[
              _CarteReglement(evenementId: evenementId, reglement: reglement),
              const SizedBox(height: PpSpacing.sm),
            ],
            const SizedBox(height: PpSpacing.lg),
          ],
          if (page.soldes.isNotEmpty) ...[
            const _Titre('Où en est chacun'),
            PpCard(
              child: Column(
                children: [
                  for (final solde in page.soldes) _LigneSolde(solde: solde),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: PpSpacing.xs, bottom: PpSpacing.sm),
    child: Text(texte, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// Ce que l'appelant doit, ou ce qu'on lui doit (`EF-RMB-05`).
///
/// En tête, et en grand : c'est la seule ligne de l'écran sur laquelle il a quelque
/// chose à faire. Les soldes des autres ne le concernent qu'ensuite.
class _MonSolde extends StatelessWidget {
  const _MonSolde({required this.montant});

  final double montant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (libelle, sens, couleur) = switch (montant) {
      > 0 => ('On te doit', PpMoneySense.crediteur, PpColors.vert),
      < 0 => ('Tu dois', PpMoneySense.debiteur, PpColors.rose),
      _ => ('Tu es à jour', PpMoneySense.neutre, PpColors.violet),
    };

    return Container(
      padding: const EdgeInsets.all(PpSpacing.lg),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PpRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: PpColors.texteSur(couleur, theme.brightness),
            ),
          ),
          if (montant != 0) ...[
            const SizedBox(height: PpSpacing.xs),
            PpMoney(
              montant.abs(),
              sense: sens,
              style: theme.textTheme.headlineMedium,
            ),
          ] else ...[
            const SizedBox(height: PpSpacing.xs),
            Text(
              'Personne ne te doit rien, et tu ne dois rien.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Un remboursement : qui rend combien à qui.
class _CarteReglement extends ConsumerStatefulWidget {
  const _CarteReglement({required this.evenementId, required this.reglement});

  final String evenementId;
  final Reglement reglement;

  @override
  ConsumerState<_CarteReglement> createState() => _CarteReglementState();
}

class _CarteReglementState extends ConsumerState<_CarteReglement> {
  bool _enCours = false;

  Reglement get _reglement => widget.reglement;

  Future<void> _agir() async {
    setState(() => _enCours = true);

    final api = ref.read(reglementsApiProvider);

    try {
      if (_reglement.effectue) {
        final id = _reglement.id;
        if (id != null) {
          await api.annuler(widget.evenementId, id);
        }
      } else {
        await api.marquerEffectue(
          widget.evenementId,
          deMembreId: _reglement.deMembreId,
          versMembreId: _reglement.versMembreId,
          montant: _reglement.montant,
        );
      }
    } on ApiException catch (erreur) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible pour le moment.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
        ref.invalidate(reglementsProvider(widget.evenementId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reglement = _reglement;

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PpAvatar(nom: reglement.deNom, taille: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: PpSpacing.sm),
                child: Icon(Icons.arrow_forward_rounded, size: 16),
              ),
              PpAvatar(nom: reglement.versNom, taille: 32),
              const SizedBox(width: PpSpacing.md),
              Expanded(
                child: Text(
                  '${reglement.deNom} rend à ${reglement.versNom}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                ),
              ),
              PpMoney(reglement.montant, style: theme.textTheme.titleMedium),
            ],
          ),
          // Le geste n'est proposé qu'aux deux personnes concernées : déclarer le
          // remboursement de deux tiers n'a pas de sens, ni l'un ni l'autre ne l'a
          // constaté.
          if (reglement.meConcerne) ...[
            const SizedBox(height: PpSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: _enCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _agir,
                      child: Text(
                        reglement.effectue ? 'Annuler' : 'C’est réglé',
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LigneSolde extends StatelessWidget {
  const _LigneSolde({required this.solde});

  final Solde solde;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sens = solde.onLuiDoit
        ? PpMoneySense.crediteur
        : solde.ilDoit
        ? PpMoneySense.debiteur
        : PpMoneySense.neutre;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PpSpacing.xs),
      child: Row(
        children: [
          PpAvatar(nom: solde.nom, taille: 32),
          const SizedBox(width: PpSpacing.md),
          Expanded(child: Text(solde.nom, style: theme.textTheme.bodyMedium)),
          PpMoney(
            solde.montant,
            sense: sens,
            afficherSigne: true,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

/// Signale que la somme des soldes n'est pas nulle (`IV-02`, `RG-RMB-04`).
///
/// Les chiffres restent affichés : les cacher priverait d'une information utile pour
/// comprendre l'écart, et laisserait croire à une panne plutôt qu'à une anomalie.
class _Avertissement extends StatelessWidget {
  const _Avertissement();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(PpSpacing.md),
      decoration: BoxDecoration(
        color: PpColors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(PpRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: PpColors.texteSur(PpColors.orange, theme.brightness),
          ),
          const SizedBox(width: PpSpacing.md),
          Expanded(
            child: Text(
              'Les comptes ne tombent pas juste. Vérifie les dépenses avant de '
              'rembourser quoi que ce soit.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Écran autonome des remboursements, atteint depuis les dépenses ou le menu.
///
/// Distinct de [ReglementsPage] : celle-ci s'insère aussi dans une coquille qui
/// fournit déjà sa barre.
class ReglementsEcran extends StatelessWidget {
  const ReglementsEcran({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context) => PpRemonteAuParent(
    versParent: PpRoutes.versEvenement(evenementId),
    child: Scaffold(
      appBar: PpBarreEvenement(
        evenementId: evenementId,
        section: 'QUI REND QUOI',
      ),
      body: PpRail(child: ReglementsPage(evenementId: evenementId)),
    ),
  );
}
