import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';

/// Seconde étape de la connexion : code temporel ou code de secours (EF-AUTH-12).
class SecondFacteurPage extends ConsumerStatefulWidget {
  const SecondFacteurPage({required this.jetonDefi, super.key});

  /// Jeton intermédiaire remis à la première étape. Il n'ouvre aucun accès par lui-même.
  final String jetonDefi;

  @override
  ConsumerState<SecondFacteurPage> createState() => _SecondFacteurPageState();
}

class _SecondFacteurPageState extends ConsumerState<SecondFacteurPage> {
  final _code = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final saisie = _code.text.trim();

    if (saisie.isEmpty) {
      setState(() => _erreur = 'Saisis le code affiché par ton application.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .verifierSecondFacteur(jetonDefi: widget.jetonDefi, code: saisie);

      if (mounted) {
        context.go(PpRoutes.accueil);
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PpSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PpAuthHeader(
                  titre: 'Code de vérification',
                  sousTitre:
                      'Saisis le code à six chiffres affiché par ton application '
                      'd’authentification.',
                ),
                const SizedBox(height: PpSpacing.xxl),
                if (_erreur != null) ...[
                  PpFormError(_erreur!),
                  const SizedBox(height: PpSpacing.lg),
                ],
                PpField(
                  label: 'Code',
                  controller: _code,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _valider(),
                  enabled: !_enCours,
                  // Le champ accepte les deux formes : refuser un code de secours ici
                  // enfermerait dehors quiconque a perdu son téléphone.
                  aide:
                      'Un code de secours au format XXXX-XXXX fonctionne également.',
                ),
                const SizedBox(height: PpSpacing.xl),
                PpPrimaryButton(
                  label: 'Vérifier',
                  enCours: _enCours,
                  onPressed: _valider,
                ),
                const SizedBox(height: PpSpacing.lg),
                Text(
                  'Le code change toutes les 30 secondes. Si aucun ne fonctionne, '
                  'vérifie que l’heure de ton téléphone est réglée automatiquement.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
