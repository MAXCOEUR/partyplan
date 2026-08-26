import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/models/activite.dart';
import '../../core/providers.dart';
import '../../design/components/pp_barre_evenement.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_remonte_au_parent.dart';
import '../../design/components/pp_skeleton.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import 'ligne_activite.dart';

/// Fil d'activité d'un événement (`EF-FIL-01`).
///
/// **Un registre, pas un fil social.** Un fil social appelle la réaction ; celui-ci
/// appelle la lecture. Rien ne s'y touche : le fil est la trace de référence en cas de
/// désaccord sur les montants (`RG-FIL-02`), et l'écran doit le rendre évident plutôt
/// que de l'écrire quelque part.
///
/// D'où l'absence de cartes, seule de toute l'application : les surfaces sur lesquelles
/// on agit sont des `PpCard`, celle-ci n'en est pas une. Le filet vertical qui relie les
/// lignes tient lieu de structure et fait lire l'ensemble comme un registre continu.
class ActivitePage extends ConsumerStatefulWidget {
  const ActivitePage({required this.evenementId, super.key});

  final String evenementId;

  @override
  ConsumerState<ActivitePage> createState() => _ActivitePageState();
}

class _ActivitePageState extends ConsumerState<ActivitePage> {
  final _defilement = ScrollController();

  /// Pages plus anciennes déjà remontées.
  ///
  /// Tenues à part de la première page, qui vient du provider et se rafraîchit au
  /// temps réel. Les lignes du fil ne changent jamais après écriture : ce qui a été
  /// remonté reste valable, et seules des lignes neuves apparaissent en tête.
  final _plusAnciennes = <Activite>[];

  bool _chargeLaSuite = false;
  bool _resteDuPasse = true;
  Object? _erreurDeSuite;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_auDefilement);
  }

  @override
  void dispose() {
    _defilement
      ..removeListener(_auDefilement)
      ..dispose();
    super.dispose();
  }

  void _auDefilement() {
    if (!_defilement.hasClients) {
      return;
    }

    final reste =
        _defilement.position.maxScrollExtent - _defilement.position.pixels;

    // Anticipé d'un écran : attendre la butée ferait apparaître un vide le temps de la
    // requête, à chaque fois.
    if (reste < _defilement.position.viewportDimension) {
      // ignore: discarded_futures
      _chargerLaSuite();
    }
  }

  Future<void> _chargerLaSuite() async {
    if (_chargeLaSuite || !_resteDuPasse || _erreurDeSuite != null) {
      return;
    }

    final premiere = ref.read(filActiviteProvider(widget.evenementId)).value;
    if (premiere == null || !premiere.encore) {
      return;
    }

    final connues = [...premiere.lignes, ..._plusAnciennes];
    if (connues.isEmpty) {
      return;
    }

    setState(() => _chargeLaSuite = true);

    try {
      final suite = await ref
          .read(activiteApiProvider)
          .lire(widget.evenementId, avant: connues.last.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _plusAnciennes.addAll(suite.lignes);
        _resteDuPasse = suite.encore;
        _chargeLaSuite = false;
      });
    } on Object catch (erreur) {
      if (!mounted) {
        return;
      }

      // L'erreur est retenue plutôt que relancée : la liste déjà chargée reste lisible,
      // et seul le bas de page annonce l'échec.
      setState(() {
        _erreurDeSuite = erreur;
        _chargeLaSuite = false;
      });
    }
  }

  void _reessayerLaSuite() {
    setState(() => _erreurDeSuite = null);
    // ignore: discarded_futures
    _chargerLaSuite();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final fil = ref.watch(filActiviteProvider(widget.evenementId));

    return PpRemonteAuParent(
      versParent: PpRoutes.versEvenement(widget.evenementId),
      child: Scaffold(
        appBar: PpBarreEvenement(
          evenementId: widget.evenementId,
          section: 'ACTIVITÉ',
        ),
        body: PpRail(
          child: fil.when(
            loading: () => const _SqueletteFil(),
            error: (_, _) => PpErrorState(
              message: l10n.filErreurTitre,
              onRetry: () =>
                  ref.invalidate(filActiviteProvider(widget.evenementId)),
            ),
            data: (page) => _corps(l10n, page),
          ),
        ),
      ),
    );
  }

  Widget _corps(PpL10n l10n, PageActivite page) {
    final lignes = [...page.lignes, ..._plusAnciennes];

    if (lignes.isEmpty) {
      return PpEmptyState(
        titre: l10n.filVideTitre,
        explication: l10n.filVideExplication,
        icone: Icons.history_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _plusAnciennes.clear();
          _resteDuPasse = true;
          _erreurDeSuite = null;
        });
        ref.invalidate(filActiviteProvider(widget.evenementId));
      },
      child: ListView.builder(
        controller: _defilement,
        padding: const EdgeInsets.symmetric(
          horizontal: PpSpacing.lg,
          vertical: PpSpacing.md,
        ),
        itemCount: lignes.length + 1,
        itemBuilder: (context, index) {
          if (index == lignes.length) {
            return _pied(l10n, page);
          }

          final activite = lignes[index];
          final precedente = index == 0 ? null : lignes[index - 1];

          return LigneActivite(
            activite: activite,
            rang: index,
            // Le jour change quand la ligne précédente appartenait à un autre
            // jour. En tête de liste, le marqueur est toujours posé.
            debuteUnJour:
                precedente == null || !_memeJour(precedente.creeLe, activite.creeLe),
            premiere: index == 0,
            derniere: index == lignes.length - 1 && !page.encore,
          );
        },
      ),
    );
  }

  Widget _pied(PpL10n l10n, PageActivite page) {
    if (_erreurDeSuite != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: PpSpacing.xl),
        child: Center(
          child: TextButton(
            onPressed: _reessayerLaSuite,
            child: Text(l10n.reessayer),
          ),
        ),
      );
    }

    if (_chargeLaSuite || (page.encore && _resteDuPasse)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: PpSpacing.xl),
        child: Center(child: PpLoadingIndicateur()),
      );
    }

    return const SizedBox(height: PpSpacing.xxl);
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Chargement initial : des lignes de registre, pas des cartes — le squelette doit
/// annoncer la forme réelle de l'écran, sinon le passage à l'état chargé fait sauter la
/// page.
class _SqueletteFil extends StatelessWidget {
  const _SqueletteFil();

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.symmetric(
      horizontal: PpSpacing.lg,
      vertical: PpSpacing.md,
    ),
    itemCount: 6,
    itemBuilder: (context, index) => Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSkeleton(hauteur: 32, largeur: 32, rayon: PpRadius.pill),
          const SizedBox(width: PpSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PpSkeleton(hauteur: 14, largeur: index.isEven ? 220 : 170),
                const SizedBox(height: PpSpacing.sm),
                const PpSkeleton(hauteur: 10, largeur: 64),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
