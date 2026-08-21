import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/retour_auth.dart';
import '../../app/router.dart';
import '../../core/models/invitation.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/marque.dart';

typedef _IdentiteInvitation = ({String? jeton, String? code});

/// Aperçu restreint d'une invitation, accessible sans session (RG-INV-04).
///
/// N'affiche que ce que porte [ApercuInvitation] : nom, date, lieu, nombre de
/// participants. **Ni liste nominative, ni dépenses, ni jeton.** Ce qui n'existe pas
/// dans le modèle ne peut pas fuiter dans cet écran.
class ApercuInvitationPage extends ConsumerStatefulWidget {
  const ApercuInvitationPage({this.jeton, this.code, super.key});

  final String? jeton;
  final String? code;

  @override
  ConsumerState<ApercuInvitationPage> createState() =>
      _ApercuInvitationPageState();
}

class _ApercuInvitationPageState extends ConsumerState<ApercuInvitationPage> {
  static final _dateFr = DateFormat('EEEE d MMMM yyyy, HH:mm', 'fr_FR');

  bool _adhesionLancee = false;
  bool _adhesionEnCours = false;
  String? _erreurAdhesion;
  int _generationAdhesion = 0;

  _IdentiteInvitation get _identiteInvitation =>
      (jeton: widget.jeton, code: widget.code);

  @override
  void didUpdateWidget(covariant ApercuInvitationPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final ancienneIdentite = (jeton: oldWidget.jeton, code: oldWidget.code);
    if (ancienneIdentite == _identiteInvitation) {
      return;
    }

    // GoRouter peut conserver ce State quand seul le paramètre de route change.
    // Toute tâche ou réponse de l'invitation précédente devient alors obsolète.
    _generationAdhesion++;
    _adhesionLancee = false;
    _adhesionEnCours = false;
    _erreurAdhesion = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final apercu = ref.watch(
      apercuInvitationProvider((jeton: widget.jeton, code: widget.code)),
    );
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(PpMarque.nom)),
      body: apercu.when(
        loading: () => const PpLoadingState(),
        error: (_, _) => PpErrorState(
          message: l10n.apercuIntrouvable,
          onRetry: () => ref.invalidate(
            apercuInvitationProvider((jeton: widget.jeton, code: widget.code)),
          ),
        ),
        data: (donnees) {
          _planifierAdhesion(donnees, session.value);

          return _Contenu(
            apercu: donnees,
            dateFr: _dateFr,
            action: _action(donnees, session),
          );
        },
      ),
    );
  }

  void _planifierAdhesion(ApercuInvitation apercu, EtatSession? etatSession) {
    if (!apercu.adhesionsOuvertes ||
        etatSession != EtatSession.connecte ||
        _adhesionLancee ||
        _adhesionEnCours ||
        _erreurAdhesion != null) {
      return;
    }

    // La garde est levée avant de programmer la tâche : plusieurs reconstructions
    // dans la même frame ne peuvent donc pas empiler plusieurs POST.
    _adhesionLancee = true;
    final identite = _identiteInvitation;
    final generation = _generationAdhesion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _estTentativeCourante(identite, generation)) {
        _rejoindre(identite, generation);
      }
    });
  }

  Widget _action(ApercuInvitation apercu, AsyncValue<EtatSession> session) {
    final l10n = PpL10n.of(context);

    if (!apercu.adhesionsOuvertes) {
      return PpCard(
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: PpColors.orange),
            const SizedBox(width: PpSpacing.md),
            Expanded(child: Text(l10n.apercuFermee)),
          ],
        ),
      );
    }

    return session.when(
      loading: () => const SizedBox(height: 64, child: PpLoadingState()),
      error: (_, _) => PpErrorState(
        message: l10n.erreurReseau,
        onRetry: () => ref.invalidate(sessionProvider),
      ),
      data: (etat) {
        if (etat == EtatSession.anonyme) {
          final destination = widget.jeton != null
              ? PpRoutes.versRejoindre(widget.jeton!)
              : PpRoutes.versApercuParCode(widget.code!);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.apercuCompteRequis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: PpSpacing.md),
              FilledButton(
                onPressed: () =>
                    context.go(RetourAuth.versConnexion(destination)),
                child: Text(l10n.apercuSeConnecter),
              ),
              const SizedBox(height: PpSpacing.sm),
              OutlinedButton(
                onPressed: () =>
                    context.go(RetourAuth.versInscription(destination)),
                child: Text(l10n.apercuCreerCompte),
              ),
            ],
          );
        }

        if (_erreurAdhesion != null) {
          return PpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _erreurAdhesion!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: PpSpacing.md),
                OutlinedButton(
                  onPressed: _reessayer,
                  child: Text(l10n.reessayer),
                ),
              ],
            ),
          );
        }

        return Semantics(
          liveRegion: true,
          label: l10n.adhesionEnCours,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: PpSpacing.md),
              Flexible(child: Text(l10n.adhesionEnCours)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rejoindre(_IdentiteInvitation identite, int generation) async {
    if (!_estTentativeCourante(identite, generation) || _adhesionEnCours) {
      return;
    }

    setState(() {
      _adhesionEnCours = true;
      _erreurAdhesion = null;
    });

    try {
      final api = ref.read(evenementsApiProvider);
      final evenementId = identite.jeton != null
          ? await api.rejoindreParJeton(jeton: identite.jeton!)
          : await api.rejoindreParCode(code: identite.code!);

      if (mounted && _estTentativeCourante(identite, generation)) {
        context.go(PpRoutes.versEvenement(evenementId));
      }
    } on Exception {
      if (mounted && _estTentativeCourante(identite, generation)) {
        setState(() {
          _adhesionEnCours = false;
          _erreurAdhesion = PpL10n.of(context).adhesionEchec;
        });
      }
    }
  }

  bool _estTentativeCourante(_IdentiteInvitation identite, int generation) =>
      generation == _generationAdhesion && identite == _identiteInvitation;

  void _reessayer() {
    if (_adhesionEnCours) {
      return;
    }

    setState(() {
      _adhesionLancee = false;
      _erreurAdhesion = null;
    });
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.apercu,
    required this.dateFr,
    required this.action,
  });

  final ApercuInvitation apercu;
  final DateFormat dateFr;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      children: [
        PpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(apercu.nom, style: theme.textTheme.headlineSmall),
              const SizedBox(height: PpSpacing.sm),
              Text(
                dateFr.format(apercu.debut),
                style: theme.textTheme.bodyMedium,
              ),
              if (apercu.adresse != null)
                Text(apercu.adresse!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: PpSpacing.md),
              Text(
                l10n.apercuParticipants(apercu.nombreParticipants),
                style: theme.textTheme.bodySmall,
              ),
              if (apercu.description != null &&
                  apercu.description!.isNotEmpty) ...[
                const SizedBox(height: PpSpacing.md),
                Text(apercu.description!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.xl),
        action,
      ],
    );
  }
}
