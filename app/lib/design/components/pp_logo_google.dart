import 'package:flutter/material.dart';

/// Le « G » de Google, dessiné à ses proportions officielles.
///
/// Tracé plutôt qu'importé : une image matricielle se voit sur un écran dense, et une
/// dépendance SVG coûterait un paquet entier pour quatre courbes. Le tracé, lui, reste
/// net à toute densité et ne pèse rien.
///
/// Les proportions sont celles de la marque et ne se retouchent pas : les directives de
/// Google interdisent d'en modifier les couleurs, l'épaisseur ou l'espacement.
class PpLogoGoogle extends StatelessWidget {
  const PpLogoGoogle({this.taille = 20, super.key});

  final double taille;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: taille,
      child: CustomPaint(painter: _Peintre()),
    ),
  );
}

class _Peintre extends CustomPainter {
  /// Côté du carré d'origine du tracé. Tout le reste en découle par une homothétie.
  static const _cote = 24.0;

  static const _bleu = Color(0xFF4285F4);
  static const _vert = Color(0xFF34A853);
  static const _jaune = Color(0xFFFBBC05);
  static const _rouge = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _cote, size.height / _cote);

    _tracer(canvas, _arcBleu(), _bleu);
    _tracer(canvas, _arcVert(), _vert);
    _tracer(canvas, _arcJaune(), _jaune);
    _tracer(canvas, _arcRouge(), _rouge);

    canvas.restore();
  }

  static void _tracer(Canvas canvas, Path chemin, Color couleur) =>
      canvas.drawPath(chemin, Paint()..color = couleur);

  /// La barre horizontale et le quart supérieur droit.
  static Path _arcBleu() => Path()
    ..moveTo(22.56, 12.25)
    ..relativeCubicTo(0, -0.78, -0.07, -1.53, -0.2, -2.25)
    ..lineTo(12, 10)
    ..relativeLineTo(0, 4.26)
    ..relativeLineTo(5.92, 0)
    ..relativeCubicTo(-0.26, 1.37, -1.04, 2.53, -2.21, 3.31)
    ..relativeLineTo(0, 2.77)
    ..relativeLineTo(3.57, 0)
    ..relativeCubicTo(2.08, -1.92, 3.28, -4.74, 3.28, -8.09)
    ..close();

  /// Le bas.
  static Path _arcVert() => Path()
    ..moveTo(12, 23)
    ..relativeCubicTo(2.97, 0, 5.46, -0.98, 7.28, -2.66)
    ..relativeLineTo(-3.57, -2.77)
    ..relativeCubicTo(-0.98, 0.66, -2.23, 1.06, -3.71, 1.06)
    ..relativeCubicTo(-2.86, 0, -5.29, -1.93, -6.16, -4.53)
    ..lineTo(2.18, 14.1)
    ..relativeLineTo(0, 2.84)
    ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
    ..close();

  /// La gauche.
  static Path _arcJaune() => Path()
    ..moveTo(5.84, 14.09)
    ..relativeCubicTo(-0.22, -0.66, -0.35, -1.36, -0.35, -2.09)
    // Reflet du point de contrôle précédent : c'est ce que dit la commande « s » du
    // tracé d'origine, transcrite ici en clair faute d'équivalent dans l'API de Path.
    ..relativeCubicTo(0, -0.73, 0.13, -1.43, 0.35, -2.09)
    ..lineTo(5.84, 7.07)
    ..lineTo(2.18, 7.07)
    ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
    ..relativeCubicTo(0, 1.78, 0.43, 3.45, 1.18, 4.93)
    ..relativeLineTo(2.85, -2.22)
    ..relativeLineTo(0.81, -0.62)
    ..close();

  /// Le haut.
  static Path _arcRouge() => Path()
    ..moveTo(12, 5.38)
    ..relativeCubicTo(1.62, 0, 3.06, 0.56, 4.21, 1.64)
    ..relativeLineTo(3.15, -3.15)
    ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
    ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
    ..relativeLineTo(3.66, 2.84)
    ..relativeCubicTo(0.87, -2.6, 3.3, -4.53, 6.16, -4.53)
    ..close();

  @override
  bool shouldRepaint(_Peintre oldDelegate) => false;
}
