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

/// Réinitialisation du mot de passe (EF-AUTH-04).
///
/// Deux étapes dans un seul écran : demande du code, puis saisie du code et du nouveau
/// mot de passe. Séparer en deux écrans obligerait à revenir en arrière pour relire le
/// code reçu.
class MotDePasseOubliePage extends ConsumerStatefulWidget {
  const MotDePasseOubliePage({super.key});

  @override
  ConsumerState<MotDePasseOubliePage> createState() =>
      _MotDePasseOubliePageState();
}

class _MotDePasseOubliePageState extends ConsumerState<MotDePasseOubliePage> {
  final _formulaire = GlobalKey<FormState>();
  final _adresse = TextEditingController();
  final _code = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  bool _codeDemande = false;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _adresse.dispose();
    _code.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _demanderCode() async {
    if (Validateurs.adresse(_adresse.text) != null) {
      _formulaire.currentState!.validate();
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(comptesApiProvider)
          .demanderReinitialisation(_adresse.text.trim());
      // Le message ne confirme jamais l'existence du compte (RG-AUTH-04).
      setState(() => _codeDemande = true);
    } on ApiException catch (erreur) {
      setState(
        () => _erreur = erreur.estTropDeRequetes
            ? PpL10n.of(context).erreurTropDeTentatives
            : erreur.title,
      );
    } on Exception {
      setState(() => _erreur = PpL10n.of(context).erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _reinitialiser() async {
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
          .reinitialiser(
            code: _code.text.trim(),
            nouveauMotDePasse: _nouveau.text,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mot de passe réinitialisé. Connecte-toi avec le nouveau.',
          ),
        ),
      );
      context.go(PpRoutes.connexion);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
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
                  PpAuthHeader(
                    titre: 'Mot de passe oublié',
                    sousTitre: _codeDemande
                        ? 'Si un compte existe avec cette adresse, un code vient de partir. '
                              'Colle-le ci-dessous.'
                        : 'Indique ton adresse : un code de réinitialisation te sera envoyé.',
                  ),
                  const SizedBox(height: PpSpacing.xxl),
                  if (_erreur != null) ...[
                    PpFormError(_erreur!),
                    const SizedBox(height: PpSpacing.lg),
                  ],
                  PpField(
                    label: 'Adresse e-mail',
                    controller: _adresse,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validateurs.adresse,
                    enabled: !_enCours && !_codeDemande,
                  ),
                  if (!_codeDemande) ...[
                    const SizedBox(height: PpSpacing.xl),
                    PpPrimaryButton(
                      label: 'Recevoir un code',
                      enCours: _enCours,
                      onPressed: _demanderCode,
                    ),
                  ] else ...[
                    const SizedBox(height: PpSpacing.lg),
                    PpField(
                      label: 'Code reçu',
                      controller: _code,
                      validator: Validateurs.code,
                      enabled: !_enCours,
                      aide: 'Valable 15 minutes, utilisable une seule fois.',
                    ),
                    const SizedBox(height: PpSpacing.lg),
                    PpField(
                      label: 'Nouveau mot de passe',
                      controller: _nouveau,
                      obscure: true,
                      validator: Validateurs.motDePasse,
                      enabled: !_enCours,
                      aide:
                          'De ${Validateurs.longueurMotDePasse} à ${Validateurs.longueurMaximaleMotDePasse} caractères, avec une majuscule, une minuscule, un chiffre et un caractère spécial.',
                    ),
                    const SizedBox(height: PpSpacing.lg),
                    PpField(
                      label: 'Confirme le mot de passe',
                      controller: _confirmation,
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !_enCours,
                      textInputAction: TextInputAction.done,
                      validator: (valeur) =>
                          Validateurs.confirmation(_nouveau.text, valeur),
                      onSubmitted: (_) => _reinitialiser(),
                      // Une faute de frappe sur un champ masqué ne se voit pas : sans
                      // cette seconde saisie, la personne se retrouverait enfermée
                      // dehors avec un mot de passe qu'elle croit connaître.
                      aide: 'La même, pour écarter une faute de frappe.',
                    ),
                    const SizedBox(height: PpSpacing.xl),
                    PpPrimaryButton(
                      label: 'Changer mon mot de passe',
                      enCours: _enCours,
                      onPressed: _reinitialiser,
                    ),
                    const SizedBox(height: PpSpacing.md),
                    Text(
                      'Toutes tes sessions seront déconnectées.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: _enCours ? null : _demanderCode,
                      child: const Text('Renvoyer un code'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
