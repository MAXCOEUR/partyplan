import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/validateurs.dart';

/// Changement de mot de passe imposé, avant toute autre action (RG-ADM-10).
///
/// Le compte administrateur amorcé porte un mot de passe inscrit dans un fichier de
/// configuration : le serveur refuse toute autre requête en 403 tant qu'il n'a pas
/// changé. Sans cet écran, la personne resterait sur un accueil vide, chaque lecture
/// refusée sans explication.
///
/// L'écran de sécurité ne convient pas ici : il lit les sessions et les moyens de
/// connexion, deux appels que le serveur refuse justement dans cet état.
class MotDePasseAChangerPage extends ConsumerStatefulWidget {
  const MotDePasseAChangerPage({super.key});

  @override
  ConsumerState<MotDePasseAChangerPage> createState() =>
      _MotDePasseAChangerPageState();
}

class _MotDePasseAChangerPageState
    extends ConsumerState<MotDePasseAChangerPage> {
  final _formulaire = GlobalKey<FormState>();
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _actuel.dispose();
    _nouveau.dispose();
    super.dispose();
  }

  Future<void> _changer() async {
    if (!_formulaire.currentState!.validate()) {
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(comptesApiProvider)
          .changerMotDePasse(actuel: _actuel.text, nouveau: _nouveau.text);

      // Sans cette remise à zéro, le routeur ramènerait aussitôt sur cet écran : le
      // drapeau est ce qui déclenche la redirection.
      ref.read(motDePasseAChangerProvider.notifier).satisfait();
      ref.invalidate(profilProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe changé. Bienvenue.')),
      );
      context.go(PpRoutes.accueil);
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpL10n.of(context).erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _deconnecter() async {
    await ref.read(sessionProvider.notifier).deconnecter();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PpSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formulaire,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PpAuthHeader(
                    titre: 'Change ton mot de passe',
                    sousTitre:
                        'Ce compte a été créé avec un mot de passe connu. '
                        'Choisis-en un nouveau pour continuer.',
                  ),
                  const SizedBox(height: PpSpacing.xxl),
                  if (_erreur != null) ...[
                    PpFormError(_erreur!),
                    const SizedBox(height: PpSpacing.lg),
                  ],
                  PpField(
                    label: 'Mot de passe actuel',
                    controller: _actuel,
                    obscure: true,
                    enabled: !_enCours,
                    validator: Validateurs.motDePasseExistant,
                  ),
                  const SizedBox(height: PpSpacing.lg),
                  PpField(
                    label: 'Nouveau mot de passe',
                    controller: _nouveau,
                    obscure: true,
                    enabled: !_enCours,
                    validator: Validateurs.motDePasse,
                    aide:
                        '${Validateurs.longueurMotDePasse} caractères minimum. '
                        'Les mots de passe déjà divulgués sont refusés.',
                  ),
                  const SizedBox(height: PpSpacing.xl),
                  PpPrimaryButton(
                    label: 'Changer et continuer',
                    enCours: _enCours,
                    onPressed: _changer,
                  ),
                  const SizedBox(height: PpSpacing.md),
                  // Une porte de sortie reste nécessaire : sans elle, un compte
                  // partagé resterait bloqué sur cet écran sans pouvoir en changer.
                  TextButton(
                    onPressed: _enCours ? null : _deconnecter,
                    child: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
