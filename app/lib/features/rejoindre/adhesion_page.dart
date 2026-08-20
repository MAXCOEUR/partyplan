import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/models/membre.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_status_chip.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../evenement/presence_vers_pastille.dart';

/// Adhésion sans compte (EF-INV-04, RG-INV-05).
///
/// **Deux écrans, jamais trois** : saisie du prénom, puis choix du statut.
///
/// Le critère d'acceptation est chiffré : de l'ouverture du lien à l'affichage du
/// tableau de bord, **trois interactions au maximum et aucune saisie d'adresse**. Le
/// décompte tenu ici : appui sur « Participer » depuis l'aperçu, saisie du prénom
/// validée au clavier, choix du statut. La validation clavier **est** l'interaction —
/// ajouter un bouton « suivant » en ferait une quatrième et ferait échouer EF-INV-04.
class AdhesionPage extends ConsumerStatefulWidget {
  const AdhesionPage({this.jeton, this.code, super.key});

  final String? jeton;
  final String? code;

  @override
  ConsumerState<AdhesionPage> createState() => _AdhesionPageState();
}

class _AdhesionPageState extends ConsumerState<AdhesionPage> {
  final _prenom = TextEditingController();

  bool _statutDemande = false;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _prenom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.lg),
          child: _statutDemande ? _choixStatut(l10n) : _saisiePrenom(l10n),
        ),
      ),
    );
  }

  Widget _saisiePrenom(PpL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PpSpacing.xxl),
      Text(
        l10n.adhesionPrenomQuestion,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: PpSpacing.xl),
      PpField(
        label: l10n.adhesionPrenomChamp,
        controller: _prenom,
        textInputAction: TextInputAction.done,
        aide: l10n.adhesionSansCompte,
        // La validation clavier passe directement à l'écran suivant : c'est ce qui
        // tient le compte à trois interactions.
        onSubmitted: (_) => _passerAuStatut(l10n),
      ),
      if (_erreur != null) PpFormError(_erreur!),
      const SizedBox(height: PpSpacing.lg),
      PpPrimaryButton(
        label: l10n.creationSuite,
        onPressed: () => _passerAuStatut(l10n),
      ),
    ],
  );

  Widget _choixStatut(PpL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PpSpacing.xxl),
      Text(
        l10n.adhesionStatutQuestion,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: PpSpacing.xl),
      for (final statut in _proposes)
        Padding(
          padding: const EdgeInsets.only(bottom: PpSpacing.md),
          child: InkWell(
            key: ValueKey('adhesion-${statut.versApi}'),
            onTap: _enCours ? null : () => _rejoindre(statut),
            borderRadius: BorderRadius.circular(PpRadius.card),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(PpSpacing.md),
              child: PpStatusChip(presence: versPastille(statut)),
            ),
          ),
        ),
      if (_erreur != null) PpFormError(_erreur!),
    ],
  );

  static const _proposes = [
    StatutPresence.present,
    StatutPresence.peutEtre,
    StatutPresence.enRetard,
    StatutPresence.partAvant,
    StatutPresence.absent,
  ];

  void _passerAuStatut(PpL10n l10n) {
    if (_prenom.text.trim().isEmpty) {
      setState(() => _erreur = l10n.adhesionPrenomRequis);
      return;
    }

    setState(() {
      _erreur = null;
      _statutDemande = true;
    });
  }

  Future<void> _rejoindre(StatutPresence statut) async {
    final l10n = PpL10n.of(context);
    final api = ref.read(evenementsApiProvider);

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final evenementId = widget.jeton != null
          ? await api.rejoindreParJeton(
              jeton: widget.jeton!,
              prenom: _prenom.text.trim(),
              statut: statut,
            )
          : await api.rejoindreParCode(
              code: widget.code!,
              prenom: _prenom.text.trim(),
              statut: statut,
            );

      await ref.read(sessionProvider.notifier).reprendreCommeInvite();

      if (mounted) {
        // `go` et non `push` : un retour arrière ne doit pas ramener sur le formulaire
        // d'une adhésion déjà faite.
        context.go(PpRoutes.versEvenement(evenementId));
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = l10n.adhesionEchec;
        });
      }
    }
  }
}
