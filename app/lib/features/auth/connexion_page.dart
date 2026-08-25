import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/retour_auth.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_auth_shell.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import 'bouton_google.dart';
import '../../l10n/validateurs.dart';

/// Écran de connexion (EF-AUTH-02).
class ConnexionPage extends ConsumerStatefulWidget {
  const ConnexionPage({this.retour, super.key});

  final String? retour;

  @override
  ConsumerState<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends ConsumerState<ConnexionPage> {
  final _formulaire = GlobalKey<FormState>();
  final _adresse = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _adresse.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formulaire.currentState!.validate()) {
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .connecter(email: _adresse.text.trim(), motDePasse: _motDePasse.text);

      if (mounted) {
        context.go(RetourAuth.destination(widget.retour));
      }
    } on ApiException catch (erreur) {
      // Le message vient du serveur : il est déjà rédigé pour l'utilisateur, et ne
      // distingue pas adresse inconnue de mot de passe erroné (RG-AUTH-04).
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpL10n.of(context).erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  /// Connexion par Google. Une annulation ne produit rien : c'est un geste ordinaire,
  /// pas un échec, et une erreur rouge pour cela serait une punition.
  Future<void> _connecterAvecGoogle(String jeton) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref.read(sessionProvider.notifier).connecterAvecGoogle(jeton);

      if (mounted) {
        context.go(RetourAuth.destination(widget.retour));
      }
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
  Widget build(BuildContext context) => PpAuthShell(
    cleFormulaire: _formulaire,
    enfants: [
      const PpAuthHeader(
        titre: 'Content de te revoir',
        sousTitre: 'Connecte-toi pour retrouver tes événements.',
      ),
      const SizedBox(height: PpSpacing.xxl),
      if (_erreur != null) ...[
        PpFormError(_erreur!),
        const SizedBox(height: PpSpacing.lg),
      ],
      PpField(
        label: 'Adresse e-mail',
        controller: _adresse,
        hint: 'prenom@exemple.fr',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        validator: Validateurs.adresse,
        enabled: !_enCours,
      ),
      const SizedBox(height: PpSpacing.lg),
      PpField(
        label: 'Mot de passe',
        controller: _motDePasse,
        obscure: true,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        validator: Validateurs.motDePasseExistant,
        onSubmitted: (_) => _valider(),
        enabled: !_enCours,
      ),
      const SizedBox(height: PpSpacing.sm),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _enCours
              ? null
              : () => context.push(PpRoutes.motDePasseOublie),
          child: const Text('Mot de passe oublié ?'),
        ),
      ),
      const SizedBox(height: PpSpacing.lg),
      PpPrimaryButton(
        label: 'Se connecter',
        enCours: _enCours,
        onPressed: _valider,
      ),
      const SizedBox(height: PpSpacing.lg),
      // Le composant décide seul de s'afficher, et sous quelle forme :
      // le bouton de l'application sur Android, celui rendu par le SDK
      // Google sur navigateur, rien si l'instance n'a pas la clé.
      BoutonGoogle(desactive: _enCours, onJeton: _connecterAvecGoogle),
      const SizedBox(height: PpSpacing.xl),
      // `Wrap` et non `Row` : sur un écran étroit, la ligne débordait
      // de plus de cent pixels. Le repli est ici préférable à une
      // troncature du libellé.
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Pas encore de compte ?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: _enCours
                ? null
                : () => context.push(
                    RetourAuth.versInscription(
                      RetourAuth.destination(widget.retour),
                    ),
                  ),
            child: const Text('Créer un compte'),
          ),
        ],
      ),
    ],
  );
}
