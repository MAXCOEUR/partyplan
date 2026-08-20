import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/offline/etat_reseau.dart';
import '../../core/providers.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../tokens.dart';

/// Bandeau de fraîcheur, affiché quand l'écran montre l'état en cache.
///
/// La date est le contenu, pas la décoration : sans elle, l'utilisateur ne distingue
/// pas un état ancien d'un état courant et décide sur des chiffres périmés.
class PpBandeauHorsLigne extends ConsumerWidget {
  const PpBandeauHorsLigne({this.onReessayer, super.key});

  static final _horodatage = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `EtatReseau` est un ChangeNotifier de Flutter : on s'y abonne par
    // `ListenableBuilder` **à l'intérieur** du widget, et non en passant l'objet depuis
    // l'écran appelant. Mélanger les deux systèmes de réactivité au point d'appel
    // faisait reconstruire l'écran entier à chaque changement d'état réseau.
    return ListenableBuilder(
      listenable: ref.watch(etatReseauProvider),
      builder: (context, _) => _contenu(context, ref.read(etatReseauProvider)),
    );
  }

  Widget _contenu(BuildContext context, EtatReseau etat) {
    if (etat.mode == ModeReseau.enLigne && etat.enAttente == 0) {
      return const SizedBox.shrink();
    }

    final l10n = PpL10n.of(context);
    final fraicheur = etat.fraicheur;

    final lignes = <String>[
      if (fraicheur != null)
        l10n.horsLigneDonneesDu(_horodatage.format(fraicheur)),
      if (etat.enAttente > 0) l10n.horsLigneEnAttente(etat.enAttente),
    ];

    return Semantics(
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.all(PpSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded),
              const SizedBox(width: PpSpacing.sm),
              Expanded(child: Text(lignes.join(' · '))),
              if (onReessayer != null)
                TextButton(
                  onPressed: onReessayer,
                  child: Text(l10n.horsLigneReessayer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
