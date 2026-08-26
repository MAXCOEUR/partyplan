import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/avis.dart';
import '../../core/providers.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Préférences de notification, par catégorie (`EF-NOT-07`).
///
/// Chaque catégorie est nommée par ce qu'elle apporte, jamais par son identifiant :
/// « Réponses aux invitations » et non `invitation.answer`. Une personne coupe ce qui
/// l'importune, elle ne configure pas un système.
///
/// La plage de silence est annoncée en pied d'écran plutôt que cachée dans une aide :
/// savoir que rien n'arrive la nuit évite de tout couper par précaution.
class PreferencesNotificationsPage extends ConsumerWidget {
  const PreferencesNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesAvisProvider);

    return Scaffold(
      appBar: PpBarreApp(titre: Text(l10n.preferencesAvisTitre)),
      body: PpRail(
        child: preferences.when(
          loading: () => const PpLoadingState(),
          error: (_, _) => PpErrorState(
            message: l10n.avisErreurTitre,
            onRetry: () => ref.invalidate(preferencesAvisProvider),
          ),
          data: (liste) => ListView(
            padding: const EdgeInsets.all(PpSpacing.lg),
            children: [
              Text(
                l10n.preferencesAvisExplication,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: PpSpacing.lg),
              PpCard(
                child: Column(
                  children: [
                    for (final preference in liste)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_nom(l10n, preference.categorie)),
                        value: preference.poussee,
                        onChanged: (actif) => _basculer(ref, preference, actif),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: PpSpacing.lg),
              Text(
                l10n.preferencesAvisSilence,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? PpColors.texteSecondaireSombre
                      : PpColors.texteSecondaireClair,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _basculer(
    WidgetRef ref,
    PreferenceAvis preference,
    bool actif,
  ) async {
    await ref
        .read(avisApiProvider)
        .definirPreference(preference.avec(poussee: actif));

    ref.invalidate(preferencesAvisProvider);
  }

  /// Nom lisible d'une catégorie.
  ///
  /// Une catégorie inconnue — écrite par une version plus récente du serveur — retombe
  /// sur son identifiant plutôt que de disparaître : mieux vaut une ligne au nom
  /// technique qu'un réglage qu'on ne peut plus couper.
  static String _nom(PpL10n l10n, String categorie) => switch (categorie) {
    'invitation.answer' => l10n.categorieReponses,
    'event.changed' => l10n.categorieChangements,
    'invitation.pending' => l10n.categorieRelances,
    'shopping.unclaimed' => l10n.categorieCourses,
    'event.starting_soon' => l10n.categorieDebut,
    'balance.due' => l10n.categorieDettes,
    'activity' => l10n.categorieActivite,
    _ => categorie,
  };
}
