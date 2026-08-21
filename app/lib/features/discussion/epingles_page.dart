import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/message.dart';
import '../../core/network/api_exception.dart';
import '../../app/router.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_barre_evenement.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_remonte_au_parent.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import 'epingler_feuille.dart';

/// Messages épinglés d'un événement, rangés par dossier (`EF-MSG-05`).
///
/// C'est le pendant du fil : la conversation défile et se perd, l'épingle reste. Les
/// dossiers y servent de rayonnages — le code du portail, l'adresse, la playlist — et
/// ce qui n'est pas rangé demeure visible plutôt que de disparaître dans un
/// fourre-tout.
class EpinglesPage extends ConsumerStatefulWidget {
  const EpinglesPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  ConsumerState<EpinglesPage> createState() => _EpinglesPageState();
}

class _EpinglesPageState extends ConsumerState<EpinglesPage> {
  /// Dossier affiché. Nul pour tout voir.
  String? _filtre;

  /// Vrai pour ne montrer que ce qui n'est rangé nulle part.
  bool _sansDossier = false;

  @override
  Widget build(BuildContext context) {
    final epingles = ref.watch(epinglesProvider(widget.evenementId));

    return PpRemonteAuParent(
      versParent: PpRoutes.versEvenement(widget.evenementId),
      child: Scaffold(
        appBar: PpBarreEvenement(
          evenementId: widget.evenementId,
          section: 'ÉPINGLÉ',
        ),
        body: PpRail(
          child: epingles.when(
            loading: () => const PpLoadingState(),
            error: (_, _) => PpErrorState(
              message: 'Impossible de charger les messages épinglés.',
              onRetry: () =>
                  ref.invalidate(epinglesProvider(widget.evenementId)),
            ),
            data: (page) => _Contenu(
              evenementId: widget.evenementId,
              page: page,
              filtre: _filtre,
              sansDossier: _sansDossier,
              onFiltre: (dossierId, sansDossier) => setState(() {
                _filtre = dossierId;
                _sansDossier = sansDossier;
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({
    required this.evenementId,
    required this.page,
    required this.filtre,
    required this.sansDossier,
    required this.onFiltre,
  });

  final String evenementId;
  final PageEpingles page;
  final String? filtre;
  final bool sansDossier;
  final void Function(String? dossierId, bool sansDossier) onFiltre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.estVide) {
      return const PpEmptyState(
        titre: 'Rien d’épinglé',
        explication:
            'Dans la discussion, ouvre le menu d’un message et choisis '
            '« Épingler ». Le code du portail ou l’adresse se retrouvent ici, '
            'sans remonter la conversation.',
        icone: Icons.push_pin_rounded,
      );
    }

    // Le filtre est appliqué ici : le serveur a déjà renvoyé tout le contenu, et un
    // aller-retour par dossier ferait clignoter la liste sans rien apporter.
    final retenues = page.epingles.where((epingle) {
      if (sansDossier) {
        return epingle.dossierId == null;
      }
      return filtre == null || epingle.dossierId == filtre;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(epinglesProvider(evenementId)),
      child: ListView(
        padding: const EdgeInsets.all(PpSpacing.lg),
        children: [
          _Rayonnages(
            page: page,
            filtre: filtre,
            sansDossier: sansDossier,
            onFiltre: onFiltre,
          ),
          const SizedBox(height: PpSpacing.lg),
          if (retenues.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: PpSpacing.xl),
              child: Text(
                'Ce dossier est vide.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          for (final epingle in retenues) ...[
            _CarteEpingle(evenementId: evenementId, epingle: epingle),
            const SizedBox(height: PpSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Dossiers, en filtres. « Tout » et « Sans dossier » encadrent la liste.
class _Rayonnages extends StatelessWidget {
  const _Rayonnages({
    required this.page,
    required this.filtre,
    required this.sansDossier,
    required this.onFiltre,
  });

  final PageEpingles page;
  final String? filtre;
  final bool sansDossier;
  final void Function(String? dossierId, bool sansDossier) onFiltre;

  @override
  Widget build(BuildContext context) {
    final nonRangees = page.epingles.where((e) => e.dossierId == null).length;

    return Wrap(
      spacing: PpSpacing.sm,
      runSpacing: PpSpacing.sm,
      children: [
        ChoiceChip(
          key: const Key('filtre-tout'),
          label: Text('Tout (${page.epingles.length})'),
          selected: filtre == null && !sansDossier,
          onSelected: (_) => onFiltre(null, false),
        ),
        for (final dossier in page.dossiers)
          ChoiceChip(
            key: Key('filtre-dossier-${dossier.id}'),
            avatar: const Icon(Icons.folder_outlined, size: 16),
            label: Text('${dossier.nom} (${dossier.nombre})'),
            selected: filtre == dossier.id,
            onSelected: (_) => onFiltre(dossier.id, false),
          ),
        // Ce qui n'est rangé nulle part reste visible : classer est facultatif, et un
        // fourre-tout invisible ferait perdre ce qu'on venait d'épingler.
        if (nonRangees > 0)
          ChoiceChip(
            key: const Key('filtre-sans-dossier'),
            label: Text('Sans dossier ($nonRangees)'),
            selected: sansDossier,
            onSelected: (_) => onFiltre(null, true),
          ),
      ],
    );
  }
}

class _CarteEpingle extends ConsumerWidget {
  const _CarteEpingle({required this.evenementId, required this.epingle});

  static final _quand = DateFormat('d MMM à HH:mm', 'fr_FR');

  final String evenementId;
  final Epingle epingle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final message = epingle.message;

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PpAvatar(nom: message.auteur, taille: 28),
              const SizedBox(width: PpSpacing.sm),
              Expanded(
                child: Text(
                  '${message.auteur} · ${_quand.format(message.envoyeLe)}',
                  style: theme.textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Rangement(nom: epingle.dossierNom),
              PopupMenuButton<String>(
                key: Key('menu-epingle-${epingle.id}'),
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onSelected: (choix) => _agir(context, ref, choix),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'ranger',
                    child: Text('Ranger ailleurs'),
                  ),
                  PopupMenuItem(
                    value: 'retirer',
                    child: Text('Retirer l’épingle'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: PpSpacing.xs),
          if (message.porteUneImage)
            Padding(
              padding: const EdgeInsets.only(bottom: PpSpacing.xs),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PpRadius.md),
                child: Image.network(
                  message.urlPieceJointe!,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      const Text('Image indisponible'),
                ),
              ),
            ),
          Text(
            message.corps ?? 'Message supprimé',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _agir(BuildContext context, WidgetRef ref, String choix) async {
    final api = ref.read(discussionApiProvider);

    try {
      switch (choix) {
        case 'retirer':
          await api.desepingler(evenementId, epingle.message.id);

        case 'ranger':
          if (context.mounted) {
            // La même feuille sert à ranger : réépingler déplace au lieu d'échouer.
            await ouvrirFeuilleEpingler(
              context,
              evenementId,
              epingle.message.id,
            );
          }
      }
    } on ApiException catch (erreur) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible pour le moment.')),
        );
      }
    } finally {
      ref
        ..invalidate(epinglesProvider(evenementId))
        ..invalidate(filDiscussionProvider(evenementId));
    }
  }
}

/// Étiquette du dossier, ou son absence.
class _Rangement extends StatelessWidget {
  const _Rangement({required this.nom});

  final String? nom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = nom != null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PpSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: range
            ? PpColors.violet.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(PpRadius.pill),
      ),
      child: Text(
        nom ?? 'Sans dossier',
        style: theme.textTheme.labelSmall?.copyWith(
          color: range
              ? PpColors.texteSur(PpColors.violet, theme.brightness)
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
