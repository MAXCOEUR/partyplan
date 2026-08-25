import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

/// Bouton rendu par le SDK Google, seul parcours accepté sur navigateur.
///
/// Sa forme est imposée par Google : ni la couleur, ni la typographie, ni le libellé
/// ne suivent la charte. C'est le prix du seul chemin que le greffon autorise, et
/// c'est aussi le bouton que les gens reconnaissent d'un site à l'autre.
///
/// Le résultat du clic ne revient pas par cet appel : il arrive par le flux
/// d'événements d'authentification, que `ServiceGoogle.jetons` expose.
Widget? boutonRenduGoogle() => google_web.renderButton();
