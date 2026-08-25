import 'package:flutter/material.dart';

import '../tokens.dart';

/// Apparition d'un élément de liste, décalée selon son rang.
///
/// Une seule animation dans tout le produit, et un seul motif : une montée de huit
/// pixels avec un fondu, décalée par ligne. Le décalage s'arrête au sixième élément —
/// au-delà, l'attente devient perceptible et l'effet se retourne contre son but.
///
/// Elle ne se déclenche qu'à la première composition, jamais à un changement d'état :
/// rejouer l'apparition à chaque relecture ferait clignoter l'écran à chaque message
/// reçu, ce qui est précisément ce que le temps réel vient d'introduire.
class PpApparition extends StatefulWidget {
  const PpApparition({required this.child, this.rang = 0, super.key});

  final Widget child;

  /// Rang dans la liste. Fixe le décalage de départ.
  final int rang;

  /// Au-delà, tous les éléments partent ensemble.
  static const rangsDecales = 6;

  @override
  State<PpApparition> createState() => _PpApparitionState();
}

class _PpApparitionState extends State<PpApparition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: PpDuration.normale,
  );

  late final Animation<double> _courbe = CurvedAnimation(
    parent: _controleur,
    // Décélération : l'élément arrive vite puis se pose. Une entrée en easeIn donnerait
    // l'impression qu'il hésite avant de démarrer.
    curve: Easing.emphasizedDecelerate,
  );

  bool _lance = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_lance) {
      return;
    }

    _lance = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controleur.value = 1;
      return;
    }

    final rang = widget.rang.clamp(0, PpApparition.rangsDecales);
    final decalage = Duration(milliseconds: 40 * rang);

    Future<void>.delayed(decalage, () {
      if (mounted) {
        _controleur.forward();
      }
    });
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _courbe,
    builder: (context, child) => Opacity(
      opacity: _courbe.value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - _courbe.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}
