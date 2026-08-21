import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';

/// Création d'un sondage (`EF-SDG-01`).
///
/// Deux réponses au départ, une troisième à la demande : la plupart des questions de
/// soirée en comptent deux ou trois, et présenter dix champs vides ferait renoncer.
class SondageFeuille extends ConsumerStatefulWidget {
  const SondageFeuille({required this.evenementId, super.key});

  final String evenementId;

  @override
  ConsumerState<SondageFeuille> createState() => _SondageFeuilleState();
}

class _SondageFeuilleState extends ConsumerState<SondageFeuille> {
  final _formulaire = GlobalKey<FormState>();
  final _question = TextEditingController();
  final _reponses = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  /// Nombre maximal de réponses. Au-delà, un sondage ne se lit plus, il se subit.
  static const _maximum = 10;

  bool _choixMultiple = false;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _question.dispose();
    for (final reponse in _reponses) {
      reponse.dispose();
    }
    super.dispose();
  }

  Future<void> _creer() async {
    if (!_formulaire.currentState!.validate()) {
      return;
    }

    final options = _reponses
        .map((r) => r.text.trim())
        .where((r) => r.isNotEmpty)
        .toList();

    // Une seule réponse n'est pas un choix.
    if (options.length < 2) {
      setState(() => _erreur = 'Donne au moins deux réponses possibles.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(sondagesApiProvider)
          .creer(
            widget.evenementId,
            question: _question.text.trim(),
            options: options,
            choixMultiple: _choixMultiple,
          );

      ref
        ..invalidate(sondagesProvider(widget.evenementId))
        // Le sondage est annoncé dans le fil : le laisser en cache le ferait
        // apparaître seulement au prochain rechargement.
        ..invalidate(filDiscussionProvider(widget.evenementId));

      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = 'Création impossible pour le moment.');
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      child: Form(
        key: _formulaire,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouveau sondage', style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.lg),
            if (_erreur != null) ...[
              PpFormError(_erreur!),
              const SizedBox(height: PpSpacing.lg),
            ],
            PpField(
              key: const Key('sondage-question'),
              label: 'Question',
              hint: 'On commande quoi ? Tu apportes quoi ?',
              controller: _question,
              enabled: !_enCours,
              validator: (valeur) => valeur == null || valeur.trim().isEmpty
                  ? 'Pose une question.'
                  : null,
            ),
            const SizedBox(height: PpSpacing.lg),
            for (var index = 0; index < _reponses.length; index++) ...[
              PpField(
                key: Key('sondage-reponse-$index'),
                label: 'Réponse ${index + 1}',
                controller: _reponses[index],
                enabled: !_enCours,
              ),
              const SizedBox(height: PpSpacing.sm),
            ],
            if (_reponses.length < _maximum)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('sondage-ajouter-reponse'),
                  onPressed: _enCours
                      ? null
                      : () => setState(
                          () => _reponses.add(TextEditingController()),
                        ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Une réponse de plus'),
                ),
              ),
            const SizedBox(height: PpSpacing.md),
            SwitchListTile(
              key: const Key('sondage-choix-multiple'),
              contentPadding: EdgeInsets.zero,
              value: _choixMultiple,
              onChanged: _enCours
                  ? null
                  : (valeur) => setState(() => _choixMultiple = valeur),
              title: const Text('Plusieurs réponses possibles'),
              subtitle: const Text('Pour « qui apporte quoi », par exemple'),
            ),
            const SizedBox(height: PpSpacing.lg),
            PpPrimaryButton(
              label: 'Lancer le sondage',
              enCours: _enCours,
              onPressed: _creer,
            ),
            const SizedBox(height: PpSpacing.sm),
            Text(
              'Il apparaîtra dans la discussion, et se retrouvera dans les sondages.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ouvre la création d'un sondage.
Future<void> ouvrirFeuilleSondage(BuildContext context, String evenementId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (contexte) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(contexte).bottom,
        ),
        child: SondageFeuille(evenementId: evenementId),
      ),
    );
