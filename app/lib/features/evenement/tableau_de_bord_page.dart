import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../design/components/pp_bandeau_hors_ligne.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import 'sections/section_compte_a_rebours.dart';
import 'sections/section_creer_un_compte.dart';
import 'sections/section_identite.dart';
import 'sections/section_ma_presence.dart';
import 'sections/section_partage.dart';
import 'sections/section_sans_reponse.dart';
import 'sections/section_synthese_presences.dart';

/// Tableau de bord d'un événement (EF-EVT-04).
///
/// Une page composée de **sections autonomes**. Chaque section décide seule de
/// s'afficher ou non, et n'expose rien d'autre qu'elle-même : ajouter une section
/// consiste à créer un fichier dans `sections/` et à l'insérer dans cette liste.
/// C'est toute la raison d'être du découpage — B2 et B4 ne toucheront pas ce fichier
/// au-delà d'une ligne.
///
/// **RG-UI-02 n'est pas encore pleinement satisfaite** : la règle exige d'afficher les
/// articles non attribués avant l'événement, et le montant dû après. Ces deux
/// informations viennent des modules Shopping et Settlements, qui n'existent pas. Les
/// emplacements sont réservés ci-dessous.
class TableauDeBordPage extends ConsumerWidget {
  const TableauDeBordPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final evenement = ref.watch(evenementProvider(evenementId));

    return evenement.when(
      loading: () => const PpLoadingState(),
      // 404 et non « accès refusé » : dire « refusé » révélerait que la ressource
      // existe, ce que RG-SEC-02 interdit. Le message est donc le même pour un
      // événement inexistant et pour un événement hors périmètre.
      error: (_, _) => PpErrorState(
        message: l10n.tdbErreur,
        onRetry: () => ref.invalidate(evenementProvider(evenementId)),
      ),
      data: (resume) => RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(evenementProvider(evenementId))
            ..invalidate(membresProvider(evenementId));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PpSpacing.lg,
            PpSpacing.sm,
            PpSpacing.lg,
            PpSpacing.xxl,
          ),
          children: [
            ListenableBuilder(
              listenable: ref.watch(etatReseauProvider),
              builder: (context, _) =>
                  PpBandeauHorsLigne(etat: ref.read(etatReseauProvider)),
            ),
            SectionIdentite(resume: resume),
            SectionCompteARebours(resume: resume),
            SectionMaPresence(evenementId: evenementId),
            SectionSynthesePresences(
              evenementId: evenementId,
              resume: resume,
            ),
            SectionPartage(evenementId: evenementId),
            SectionSansReponse(evenementId: evenementId),
            const SectionCreerUnCompte(),
            // --- Emplacements réservés ---------------------------------------
            // B2 : SectionArticlesNonAttribues, SectionCeQueJeDois
            // B4 : SectionProchaineEtape
            // Chacune s'insère ici, sans autre modification de ce fichier.
          ],
        ),
      ),
    );
  }
}
