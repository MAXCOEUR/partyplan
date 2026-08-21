import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/models/evenement.dart';
import '../../core/models/membre.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_choix_date_heure.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Paramètres de l'événement : modifier, transférer, quitter, supprimer.
///
/// **L'ordre des blocs suit RG-ROLE-02** : un propriétaire doit transférer la propriété
/// avant de partir. Présenter « quitter » d'abord ferait découvrir l'interdiction après
/// coup, sans issue visible — un cul-de-sac.
class ParametresEvenementPage extends ConsumerStatefulWidget {
  const ParametresEvenementPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  ConsumerState<ParametresEvenementPage> createState() =>
      _ParametresEvenementPageState();
}

class _ParametresEvenementPageState
    extends ConsumerState<ParametresEvenementPage> {
  final _nom = TextEditingController();
  final _lieu = TextEditingController();
  final _description = TextEditingController();

  /// Date et heure de la soirée. Modifiables ici, et nulle part ailleurs : une date
  /// fixée à la création se décale souvent, et recréer l'événement ferait perdre les
  /// présences, les courses et les dépenses déjà saisies.
  DateTime? _debut;
  DateTime? _fin;

  bool _initialise = false;
  bool _enCours = false;

  static final _formatDate = DateFormat('dd/MM/yyyy', 'fr_FR');

  @override
  void dispose() {
    _nom.dispose();
    _lieu.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final evenement = ref.watch(evenementProvider(widget.evenementId));
    final moi = ref.watch(monMembreProvider(widget.evenementId)).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paramTitre)),
      body: evenement.when(
        loading: () => const PpLoadingState(),
        error: (_, _) => PpErrorState(
          message: l10n.tdbErreur,
          onRetry: () => ref.invalidate(evenementProvider(widget.evenementId)),
        ),
        data: (resume) {
          if (!_initialise) {
            _nom.text = resume.nom;
            _lieu.text = resume.adresse ?? '';
            _description.text = resume.description ?? '';
            _debut = resume.debut;
            _fin = resume.fin;
            _initialise = true;
          }

          final role = moi?.role ?? RoleMembre.membre;

          return ListView(
            padding: const EdgeInsets.all(PpSpacing.lg),
            children: [
              if (role.peutGerer) ...[
                _modification(l10n),
                const SizedBox(height: PpSpacing.xl),
              ],
              // Le transfert vient AVANT « quitter » : voir la note de classe.
              if (role == RoleMembre.proprietaire) ...[
                _transfert(l10n),
                const SizedBox(height: PpSpacing.md),
              ],
              _quitter(l10n, role),
              if (role.peutSupprimer) ...[
                const SizedBox(height: PpSpacing.md),
                _supprimer(l10n, resume),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _modification(PpL10n l10n) => PpCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PpField(label: l10n.creationChampNom, controller: _nom),
        const SizedBox(height: PpSpacing.md),
        PpField(label: l10n.creationChampLieu, controller: _lieu),
        const SizedBox(height: PpSpacing.md),
        PpField(
          label: l10n.creationChampDescription,
          controller: _description,
          lignes: 4,
        ),
        const SizedBox(height: PpSpacing.md),
        PpChoixDateHeure(
          libelle: 'Début',
          valeur: _debut,
          format: _formatDate,
          onChange: (valeur) => setState(() {
            _debut = valeur;
            // La fin ne peut pas précéder le début : la laisser en arrière donnerait
            // une soirée qui se termine avant de commencer.
            if (_fin != null && _fin!.isBefore(valeur)) {
              _fin = null;
            }
          }),
        ),
        const SizedBox(height: PpSpacing.md),
        PpChoixDateHeure(
          libelle: 'Fin (facultative)',
          valeur: _fin,
          format: _formatDate,
          minimum: _debut,
          onChange: (valeur) => setState(() => _fin = valeur),
        ),
        const SizedBox(height: PpSpacing.sm),
        Text(
          l10n.paramDateModifieeAvertissement,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: PpSpacing.md),
        PpPrimaryButton(
          label: l10n.paramEnregistrer,
          enCours: _enCours,
          onPressed: _enCours ? null : _enregistrer,
        ),
      ],
    ),
  );

  Widget _transfert(PpL10n l10n) => PpCard(
    onTap: _choisirRepreneur,
    child: Row(
      children: [
        const Icon(Icons.swap_horiz_rounded, color: PpColors.violet),
        const SizedBox(width: PpSpacing.md),
        Expanded(
          child: Text(
            l10n.paramTransferer,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );

  Widget _quitter(PpL10n l10n, RoleMembre role) => PpCard(
    onTap: () => _quitterEvenement(role),
    child: Row(
      children: [
        const Icon(Icons.logout_rounded),
        const SizedBox(width: PpSpacing.md),
        Expanded(
          child: Text(
            l10n.paramQuitter,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
  );

  Widget _supprimer(PpL10n l10n, ResumeEvenement resume) => PpCard(
    onTap: () => _confirmerSuppression(resume),
    child: Row(
      children: [
        const Icon(Icons.delete_outline_rounded, color: PpColors.rouge),
        const SizedBox(width: PpSpacing.md),
        Expanded(
          child: Text(
            l10n.paramSupprimer,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: PpColors.rougeTexte),
          ),
        ),
      ],
    ),
  );

  Future<void> _enregistrer() async {
    final l10n = PpL10n.of(context);
    final messager = ScaffoldMessenger.of(context);

    setState(() => _enCours = true);

    try {
      await ref
          .read(evenementsApiProvider)
          .modifier(
            widget.evenementId,
            nom: _nom.text.trim(),
            adresse: _lieu.text.trim(),
            description: _description.text.trim(),
            debut: _debut,
            fin: _fin,
          );

      ref
        ..invalidate(evenementProvider(widget.evenementId))
        ..invalidate(mesEvenementsProvider);

      messager.showSnackBar(SnackBar(content: Text(l10n.paramEnregistre)));
    } on Exception {
      messager.showSnackBar(SnackBar(content: Text(l10n.paramEchec)));
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  /// RG-ROLE-02 — un propriétaire ne peut pas partir sans transférer.
  ///
  /// Le refus est expliqué et assorti de la sortie : découvrir l'interdiction sans
  /// savoir quoi faire ensuite serait un cul-de-sac.
  Future<void> _quitterEvenement(RoleMembre role) async {
    final l10n = PpL10n.of(context);

    if (role == RoleMembre.proprietaire) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paramQuitterInterditProprietaire),
          // Libellé court : « Transférer la propriété » déborde la largeur d'un
          // téléphone lorsqu'il accompagne le message.
          action: SnackBarAction(
            label: l10n.paramTransfererCourt,
            onPressed: _choisirRepreneur,
          ),
        ),
      );
      return;
    }

    await ref.read(evenementsApiProvider).quitter(widget.evenementId);
    ref.invalidate(mesEvenementsProvider);

    if (mounted) {
      context.go(PpRoutes.accueil);
    }
  }

  Future<void> _choisirRepreneur() async {
    final l10n = PpL10n.of(context);
    final membres = await ref.read(membresProvider(widget.evenementId).future);

    // RG-ROLE-02 : la cible doit posséder un compte. Un invité sans compte ne
    // retrouverait pas l'événement depuis un autre appareil, et l'événement serait
    // orphelin au premier changement de téléphone.
    final eligibles = membres.where((m) => m.aUnCompte && !m.cestMoi).toList();

    if (!mounted) {
      return;
    }

    final cible = await showModalBottomSheet<Membre>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(PpSpacing.lg),
          children: [
            Text(
              l10n.paramTransferer,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PpSpacing.sm),
            Text(
              l10n.paramTransfererExplication,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.xs),
            Text(
              l10n.paramTransfererDevientAdmin,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.lg),
            if (eligibles.isEmpty)
              Text(l10n.paramTransfererAucun)
            else
              for (final membre in eligibles)
                ListTile(
                  key: ValueKey('repreneur-${membre.id}'),
                  title: Text(membre.nomAffiche),
                  onTap: () => Navigator.of(context).pop(membre),
                ),
          ],
        ),
      ),
    );

    if (cible == null) {
      return;
    }

    await ref
        .read(evenementsApiProvider)
        .transfererPropriete(widget.evenementId, cible.id);

    ref
      ..invalidate(membresProvider(widget.evenementId))
      ..invalidate(mesEvenementsProvider);
  }

  /// EF-EVT-07 — confirmation renforcée par saisie du nom.
  ///
  /// RG-EVT-02 exige en plus de vérifier qu'aucun règlement n'est en attente. Cette
  /// vérification suppose un contrat exposé par le module Settlements, qui n'existe
  /// pas : d'ici là, cette confirmation est la seule barrière.
  Future<void> _confirmerSuppression(ResumeEvenement resume) async {
    final l10n = PpL10n.of(context);
    final saisie = TextEditingController();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setEtat) => AlertDialog(
          title: Text(l10n.paramSupprimer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.paramSupprimerDefinitif),
              const SizedBox(height: PpSpacing.md),
              Text(l10n.paramSupprimerConfirmation(resume.nom)),
              const SizedBox(height: PpSpacing.sm),
              TextField(controller: saisie, onChanged: (_) => setEtat(() {})),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.paramAnnuler),
            ),
            FilledButton(
              onPressed: saisie.text.trim() == resume.nom
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(l10n.paramSupprimer),
            ),
          ],
        ),
      ),
    );

    saisie.dispose();

    if (confirme != true) {
      return;
    }

    await ref.read(evenementsApiProvider).supprimer(widget.evenementId);
    ref.invalidate(mesEvenementsProvider);

    if (mounted) {
      context.go(PpRoutes.accueil);
    }
  }
}
