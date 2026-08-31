import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/models/avis.dart';
import '../../core/providers.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_retour.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Réglage des notifications d'une soirée, catégorie par catégorie (`EF-NOT-09`).
///
/// **L'état de sourdine est affiché en tête, à côté des catégories, jamais caché.**
/// L'endpoint résolu exclut délibérément la sourdine de la valeur par catégorie : sur
/// une soirée en sourdine, chaque interrupteur se montrerait actif alors que rien ne
/// part. Sans ce rappel, l'écran mentirait sur ce qui va réellement arriver.
///
/// La discussion se règle en trois choix — tout, seulement les mentions, rien — plutôt
/// qu'un réglage à trois états inventé côté serveur : ils tombent des deux catégories
/// `discussion.message` et `discussion.mention` qu'`EF-NOT-07` sait déjà stocker.
class ParametresNotificationsPage extends ConsumerStatefulWidget {
  const ParametresNotificationsPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  ConsumerState<ParametresNotificationsPage> createState() =>
      _ParametresNotificationsPageState();
}

/// Catégories simples : un interrupteur chacune. La discussion est à part, voir
/// [_ChoixDiscussion].
const _categoriesSimples = [
  'invitation.answer',
  'event.changed',
  'invitation.pending',
  'shopping.unclaimed',
  'event.starting_soon',
  'balance.due',
  'activity',
  'poll.new',
  'expense.new',
];

const _categorieMessage = 'discussion.message';
const _categorieMention = 'discussion.mention';

enum _ChoixDiscussion { tout, mentions, rien }

class _ParametresNotificationsPageState
    extends ConsumerState<ParametresNotificationsPage> {
  /// Catégories dont l'écriture est en cours : un interrupteur touché deux fois de
  /// suite, avant que la première réponse revienne, ne doit pas partir deux fois.
  final _enCours = <String>{};
  bool _reinitialisationEnCours = false;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final preferences = ref.watch(
      preferencesDeSoireeProvider(widget.evenementId),
    );

    return Scaffold(
      appBar: PpBarreApp(
        bouton: PpRetour(
          versParent: PpRoutes.versParametres(widget.evenementId),
        ),
        titre: Text(l10n.paramNotifTitre),
      ),
      body: PpRail(
        child: preferences.when(
          loading: () => const PpLoadingState(),
          error: (_, _) => PpErrorState(
            message: l10n.paramNotifErreur,
            onRetry: () =>
                ref.invalidate(preferencesDeSoireeProvider(widget.evenementId)),
          ),
          data: (liste) => _Contenu(
            evenementId: widget.evenementId,
            preferences: liste,
            enCours: _enCours,
            reinitialisationEnCours: _reinitialisationEnCours,
            onEcrire: _ecrire,
            onChoisirDiscussion: _choisirDiscussion,
            onReinitialiser: _reinitialiser,
          ),
        ),
      ),
    );
  }

  Future<void> _ecrire(String categorie, bool actif) async {
    final messager = ScaffoldMessenger.of(context);
    final l10n = PpL10n.of(context);

    setState(() => _enCours.add(categorie));

    try {
      await ref
          .read(avisApiProvider)
          .definirPreferenceDeSoiree(widget.evenementId, categorie, actif);
    } on Exception {
      if (mounted) {
        messager.showSnackBar(SnackBar(content: Text(l10n.paramNotifEchec)));
      }
    } finally {
      ref.invalidate(preferencesDeSoireeProvider(widget.evenementId));

      if (mounted) {
        setState(() => _enCours.remove(categorie));
      }
    }
  }

  /// Écrit les deux préférences de la discussion comme un seul geste.
  ///
  /// Les deux PATCH sont séquentiels : si le premier passe et le second échoue, un
  /// silence sur le second laisserait l'écran dans une combinaison qu'aucun des trois
  /// choix ne représente (`SegmentedButton` n'en propose que trois). En cas d'échec, on
  /// tente donc de restaurer les deux catégories à leur valeur d'avant le choix, au
  /// mieux — un échec de cette restauration reste possible si le réseau est
  /// complètement indisponible, mais l'utilisateur en est alors averti.
  Future<void> _choisirDiscussion({
    required bool messageActuel,
    required bool mentionActuelle,
    required bool nouveauMessage,
    required bool nouvelleMention,
  }) async {
    final messager = ScaffoldMessenger.of(context);
    final l10n = PpL10n.of(context);

    setState(() {
      _enCours
        ..add(_categorieMessage)
        ..add(_categorieMention);
    });

    final api = ref.read(avisApiProvider);

    try {
      await api.definirPreferenceDeSoiree(
        widget.evenementId,
        _categorieMessage,
        nouveauMessage,
      );
      await api.definirPreferenceDeSoiree(
        widget.evenementId,
        _categorieMention,
        nouvelleMention,
      );
    } on Exception {
      try {
        await api.definirPreferenceDeSoiree(
          widget.evenementId,
          _categorieMessage,
          messageActuel,
        );
        await api.definirPreferenceDeSoiree(
          widget.evenementId,
          _categorieMention,
          mentionActuelle,
        );
      } on Exception {
        // Restauration elle-même en échec : le réseau est indisponible pour de bon.
        // L'état reste potentiellement incohérent côté serveur, mais la personne est
        // prévenue plutôt que de croire que son choix a été pris en compte.
      }

      if (mounted) {
        messager.showSnackBar(SnackBar(content: Text(l10n.paramNotifEchec)));
      }
    } finally {
      ref.invalidate(preferencesDeSoireeProvider(widget.evenementId));

      if (mounted) {
        setState(() {
          _enCours
            ..remove(_categorieMessage)
            ..remove(_categorieMention);
        });
      }
    }
  }

  Future<void> _reinitialiser(List<PreferenceDeSoiree> preferences) async {
    setState(() => _reinitialisationEnCours = true);

    try {
      final api = ref.read(avisApiProvider);

      for (final preference in preferences) {
        await api.definirPreferenceDeSoiree(
          widget.evenementId,
          preference.categorie,
          null,
        );
      }
    } finally {
      ref.invalidate(preferencesDeSoireeProvider(widget.evenementId));

      if (mounted) {
        setState(() => _reinitialisationEnCours = false);
      }
    }
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({
    required this.evenementId,
    required this.preferences,
    required this.enCours,
    required this.reinitialisationEnCours,
    required this.onEcrire,
    required this.onChoisirDiscussion,
    required this.onReinitialiser,
  });

  final String evenementId;
  final List<PreferenceDeSoiree> preferences;
  final Set<String> enCours;
  final bool reinitialisationEnCours;
  final Future<void> Function(String categorie, bool actif) onEcrire;
  final Future<void> Function({
    required bool messageActuel,
    required bool mentionActuelle,
    required bool nouveauMessage,
    required bool nouvelleMention,
  })
  onChoisirDiscussion;
  final Future<void> Function(List<PreferenceDeSoiree> preferences)
  onReinitialiser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);
    final simples = [
      for (final categorie in _categoriesSimples)
        _valeur(preferences, categorie),
    ].whereType<PreferenceDeSoiree>().toList();

    return ListView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      children: [
        Text(l10n.paramNotifExplication, style: theme.textTheme.bodyMedium),
        const SizedBox(height: PpSpacing.lg),
        _EtatSourdine(evenementId: evenementId),
        const SizedBox(height: PpSpacing.lg),
        if (preferences.isEmpty)
          PpEmptyState(
            titre: l10n.paramNotifTitre,
            explication: l10n.paramNotifVide,
          )
        else
          PpCard(
            child: Column(
              children: [
                _Discussion(
                  message: _valeur(preferences, _categorieMessage),
                  mention: _valeur(preferences, _categorieMention),
                  enCours:
                      enCours.contains(_categorieMessage) ||
                      enCours.contains(_categorieMention),
                  onChoisir: (message, mention) => onChoisirDiscussion(
                    messageActuel:
                        _valeur(preferences, _categorieMessage)?.actif ?? false,
                    mentionActuelle:
                        _valeur(preferences, _categorieMention)?.actif ?? false,
                    nouveauMessage: message,
                    nouvelleMention: mention,
                  ),
                ),
                const Divider(height: PpSpacing.xl),
                for (final preference in simples)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_nom(l10n, preference.categorie)),
                    subtitle: preference.estUnEcart
                        ? Text(l10n.paramNotifEcart)
                        : null,
                    value: preference.actif,
                    onChanged: enCours.contains(preference.categorie)
                        ? null
                        : (actif) => onEcrire(preference.categorie, actif),
                  ),
              ],
            ),
          ),
        const SizedBox(height: PpSpacing.lg),
        PpPrimaryButton(
          label: l10n.paramNotifReinitialiser,
          enCours: reinitialisationEnCours,
          onPressed: reinitialisationEnCours
              ? null
              : () => onReinitialiser(preferences),
        ),
      ],
    );
  }

  static PreferenceDeSoiree? _valeur(
    List<PreferenceDeSoiree> preferences,
    String categorie,
  ) {
    for (final preference in preferences) {
      if (preference.categorie == categorie) {
        return preference;
      }
    }

    return null;
  }

  /// Nom lisible d'une catégorie.
  ///
  /// Une catégorie inconnue — écrite par une version plus récente du serveur — retombe
  /// sur son identifiant plutôt que de disparaître : mieux vaut une ligne au nom
  /// technique qu'un réglage qu'on ne peut plus couper.
  static String _nom(PpL10n l10n, String categorie) => switch (categorie) {
    'invitation.answer' => l10n.categorieReponses,
    'event.changed' => l10n.categorieChangements,
    'invitation.pending' => l10n.categorieRelances,
    'shopping.unclaimed' => l10n.categorieCourses,
    'event.starting_soon' => l10n.categorieDebut,
    'balance.due' => l10n.categorieDettes,
    'activity' => l10n.categorieActivite,
    'poll.new' => l10n.categorieSondages,
    'expense.new' => l10n.categorieDepenses,
    _ => categorie,
  };
}

/// Trois choix pour la discussion, qui écrivent les deux préférences sous-jacentes.
///
/// Aucune valeur à trois états inventée en base : `discussion.message` et
/// `discussion.mention` restent deux booléens, ce qu'`EF-NOT-07` sait déjà stocker et
/// afficher.
class _Discussion extends StatelessWidget {
  const _Discussion({
    required this.message,
    required this.mention,
    required this.enCours,
    required this.onChoisir,
  });

  final PreferenceDeSoiree? message;
  final PreferenceDeSoiree? mention;
  final bool enCours;
  final void Function(bool message, bool mention) onChoisir;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    if (message == null || mention == null) {
      return const SizedBox.shrink();
    }

    final choix = message!.actif
        ? _ChoixDiscussion.tout
        : mention!.actif
        ? _ChoixDiscussion.mentions
        : _ChoixDiscussion.rien;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.paramNotifDiscussionTitre,
          style: theme.textTheme.titleMedium,
        ),
        if (message!.estUnEcart || mention!.estUnEcart) ...[
          const SizedBox(height: PpSpacing.xs),
          Text(
            l10n.paramNotifEcart,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: PpSpacing.sm),
        SegmentedButton<_ChoixDiscussion>(
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(
              const Size(0, PpA11y.cibleMinimale),
            ),
          ),
          segments: [
            ButtonSegment(
              value: _ChoixDiscussion.tout,
              label: Text(l10n.paramNotifDiscussionTout),
            ),
            ButtonSegment(
              value: _ChoixDiscussion.mentions,
              label: Text(l10n.paramNotifDiscussionMentions),
            ),
            ButtonSegment(
              value: _ChoixDiscussion.rien,
              label: Text(l10n.paramNotifDiscussionRien),
            ),
          ],
          selected: {choix},
          onSelectionChanged: enCours
              ? null
              : (selection) {
                  final (
                    nouveauMessage,
                    nouvelleMention,
                  ) = switch (selection.first) {
                    _ChoixDiscussion.tout => (true, true),
                    _ChoixDiscussion.mentions => (false, true),
                    _ChoixDiscussion.rien => (false, false),
                  };

                  onChoisir(nouveauMessage, nouvelleMention);
                },
        ),
      ],
    );
  }
}

/// État de sourdine de la soirée, affiché en lecture seule.
///
/// Le réglage lui-même se change depuis les paramètres de l'événement : le dupliquer
/// ici ferait deux commandes pour la même valeur, et les faire diverger serait pire que
/// de ne pas l'afficher du tout.
class _EtatSourdine extends ConsumerWidget {
  const _EtatSourdine({required this.evenementId});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);
    final sourdine = ref.watch(sourdineProvider(evenementId));

    return sourdine.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (enSourdine) => PpCard(
        child: Row(
          children: [
            Icon(
              enSourdine ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: enSourdine
                  ? PpColors.texteSur(PpColors.orange, theme.brightness)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: PpSpacing.md),
            Expanded(
              child: Text(
                enSourdine
                    ? l10n.paramNotifSourdineActive
                    : l10n.paramNotifSourdineInactive,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
