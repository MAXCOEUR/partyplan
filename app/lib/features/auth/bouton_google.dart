import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'bouton_google_rendu_stub.dart'
    if (dart.library.js_interop) 'bouton_google_rendu_web.dart';

/// Entrée « continuer avec Google » — `EF-AUTH-06`.
///
/// Ne s'affiche qu'à deux conditions réunies : l'instance possède la clé, et
/// l'application embarque un identifiant client. Il en manque une et le bouton serait
/// condamné à échouer.
///
/// Sa **forme** dépend de la plateforme, pas son existence. Android accepte d'ouvrir le
/// parcours à la demande, donc le bouton est celui de l'application. Le Web le refuse
/// et impose celui du SDK Google — moins joli, mais c'est le seul qui fonctionne, et
/// c'est celui que les gens reconnaissent partout ailleurs.
class BoutonGoogle extends ConsumerStatefulWidget {
  const BoutonGoogle({
    required this.onJeton,
    this.desactive = false,
    super.key,
  });

  /// Appelée avec le jeton d'identité obtenu, quel que soit le chemin emprunté.
  final Future<void> Function(String jetonIdentite) onJeton;

  final bool desactive;

  @override
  ConsumerState<BoutonGoogle> createState() => _BoutonGoogleState();
}

class _BoutonGoogleState extends ConsumerState<BoutonGoogle> {
  StreamSubscription<String>? _abonnement;

  @override
  void initState() {
    super.initState();

    final service = ref.read(serviceGoogleProvider);

    if (!service.disponible) {
      return;
    }

    // Le bouton rendu par Google doit exister avant qu'on puisse l'afficher, et son
    // résultat n'arrive que par le flux : les deux vont ensemble.
    // ignore: discarded_futures
    service.preparer();

    _abonnement = service.jetons.listen((jeton) {
      if (mounted) {
        // ignore: discarded_futures
        widget.onJeton(jeton);
      }
    });
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _abonnement?.cancel();
    super.dispose();
  }

  Future<void> _demander() async {
    final jeton = await ref.read(serviceGoogleProvider).obtenirJetonIdentite();

    // Annuler le sélecteur de compte est un geste ordinaire, pas un échec : il ne
    // produit rien et n'affiche aucune erreur.
    if (jeton != null && mounted) {
      await widget.onJeton(jeton);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceGoogleProvider);
    final cleInstance =
        (ref.watch(fournisseursDisponiblesProvider).value ?? const <String>{})
            .contains('google');

    if (!service.disponible || !cleInstance) {
      return const SizedBox.shrink();
    }

    if (service.parcoursProgrammatique) {
      return OutlinedButton(
        key: const Key('connexion-google'),
        onPressed: widget.desactive ? null : _demander,
        child: const Text('Continuer avec Google'),
      );
    }

    final rendu = boutonRenduGoogle();

    if (rendu == null) {
      return const SizedBox.shrink();
    }

    // Hauteur contrainte : le bouton du SDK est une vue HTML, qui sans borne tente
    // d'occuper toute la place disponible et casse la colonne.
    return Align(
      key: const Key('connexion-google-rendu'),
      child: SizedBox(
        height: 44,
        width: 260,
        child: IgnorePointer(ignoring: widget.desactive, child: rendu),
      ),
    );
  }
}
