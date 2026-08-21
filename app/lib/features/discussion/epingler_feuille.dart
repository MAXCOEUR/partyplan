import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';

/// Choix du rangement d'un message que l'on épingle (EF-MSG-05).
///
/// « Sans dossier » vient en premier, et coûte un seul appui : classer est un travail,
/// et l'imposer au moment où l'on veut simplement retenir une information ferait
/// renoncer à épingler.
///
/// Les dossiers sont partagés, sans exception. C'est ce qui rend l'épingle utile :
/// retrouver le code du portail que quelqu'un d'autre a donné.
class EpinglerFeuille extends ConsumerStatefulWidget {
  const EpinglerFeuille({
    required this.evenementId,
    required this.messageId,
    super.key,
  });

  final String evenementId;
  final String messageId;

  @override
  ConsumerState<EpinglerFeuille> createState() => _EpinglerFeuilleState();
}

class _EpinglerFeuilleState extends ConsumerState<EpinglerFeuille> {
  final _nouveauDossier = TextEditingController();

  bool _enCours = false;
  bool _creationOuverte = false;
  String? _erreur;

  @override
  void dispose() {
    _nouveauDossier.dispose();
    super.dispose();
  }

  Future<void> _epingler({String? dossierId}) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(discussionApiProvider)
          .epingler(widget.evenementId, widget.messageId, dossierId: dossierId);

      ref
        ..invalidate(filDiscussionProvider(widget.evenementId))
        ..invalidate(epinglesProvider(widget.evenementId));

      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = 'Épinglage impossible pour le moment.');
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _creerPuisEpingler() async {
    final nom = _nouveauDossier.text.trim();

    if (nom.isEmpty) {
      setState(() => _erreur = 'Donne un nom au dossier.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final dossier = await ref
          .read(discussionApiProvider)
          .creerDossier(widget.evenementId, nom);

      ref.invalidate(epinglesProvider(widget.evenementId));

      await _epingler(dossierId: dossier.id);
    } on ApiException catch (erreur) {
      setState(() {
        _erreur = erreur.title;
        _enCours = false;
      });
    } on Exception {
      setState(() {
        _erreur = 'Création impossible pour le moment.';
        _enCours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final epingles = ref.watch(epinglesProvider(widget.evenementId));
    final dossiers = epingles.value?.dossiers ?? [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PpSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Épingler ce message', style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.xs),
            Text(
              'Tout le monde le retrouvera ici.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.lg),
            if (_erreur != null) ...[
              PpFormError(_erreur!),
              const SizedBox(height: PpSpacing.md),
            ],
            ListTile(
              key: const Key('epingler-sans-dossier'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Sans dossier'),
              subtitle: const Text('À ranger plus tard, ou jamais'),
              enabled: !_enCours,
              onTap: () => _epingler(),
            ),
            for (final dossier in dossiers)
              ListTile(
                key: Key('epingler-dossier-${dossier.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: Text(dossier.nom),
                subtitle: Text(
                  dossier.nombre == 1
                      ? '1 message'
                      : '${dossier.nombre} messages',
                ),
                enabled: !_enCours,
                onTap: () => _epingler(dossierId: dossier.id),
              ),
            const Divider(),
            if (!_creationOuverte)
              ListTile(
                key: const Key('epingler-nouveau-dossier'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Nouveau dossier…'),
                enabled: !_enCours,
                onTap: () => setState(() => _creationOuverte = true),
              )
            else ...[
              PpField(
                key: const Key('epingler-nom-dossier'),
                label: 'Nom du dossier',
                hint: 'Musique, Adresses, Photos…',
                controller: _nouveauDossier,
                enabled: !_enCours,
              ),
              const SizedBox(height: PpSpacing.md),
              PpPrimaryButton(
                label: 'Créer et épingler',
                enCours: _enCours,
                onPressed: _creerPuisEpingler,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ouvre le choix de rangement d'une épingle.
Future<void> ouvrirFeuilleEpingler(
  BuildContext context,
  String evenementId,
  String messageId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (contexte) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(contexte).bottom),
    child: EpinglerFeuille(evenementId: evenementId, messageId: messageId),
  ),
);
