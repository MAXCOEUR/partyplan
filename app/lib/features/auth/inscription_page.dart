import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/retour_auth.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_auth_shell.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/validateurs.dart';

/// Écran d'inscription (EF-AUTH-01).
class InscriptionPage extends ConsumerStatefulWidget {
  const InscriptionPage({this.retour, super.key});

  final String? retour;

  @override
  ConsumerState<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends ConsumerState<InscriptionPage> {
  final _formulaire = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _adresse = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _prenom.dispose();
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
          .inscrire(
            email: _adresse.text.trim(),
            motDePasse: _motDePasse.text,
            nomAffiche: _prenom.text.trim(),
          );

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
    barre: AppBar(),
    enfants: [
      const PpAuthHeader(
        titre: 'Créer ton compte',
        sousTitre:
            'Pour organiser tes propres soirées et retrouver celles où tu es invité.',
      ),
      const SizedBox(height: PpSpacing.xxl),
      if (_erreur != null) ...[
        PpFormError(_erreur!),
        const SizedBox(height: PpSpacing.lg),
      ],
      PpField(
        label: 'Prénom',
        controller: _prenom,
        hint: 'Maxence',
        autofillHints: const [AutofillHints.givenName],
        textInputAction: TextInputAction.next,
        validator: Validateurs.prenom,
        enabled: !_enCours,
        aide: 'C’est le nom que verront les autres participants.',
      ),
      const SizedBox(height: PpSpacing.lg),
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
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        validator: Validateurs.motDePasse,
        onSubmitted: (_) => _valider(),
        enabled: !_enCours,
        // La règle est énoncée avant la faute, pas seulement après.
        aide:
            '${Validateurs.longueurMotDePasse} caractères minimum. '
            'Une phrase est plus facile à retenir qu’un mot compliqué, '
            'et plus difficile à deviner.',
      ),
      const SizedBox(height: PpSpacing.xl),
      PpPrimaryButton(
        label: 'Créer mon compte',
        enCours: _enCours,
        onPressed: _valider,
      ),
      const SizedBox(height: PpSpacing.lg),
      Text(
        'Un code de confirmation te sera envoyé par courriel.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
