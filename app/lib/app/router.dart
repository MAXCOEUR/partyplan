import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accueil/accueil_page.dart';
import '../features/evenement/coquille_evenement.dart';
import '../features/rejoindre/rejoindre_page.dart';
import '../l10n/pp_strings.dart';

/// Routes de l'application.
///
/// `/join/:token` est déclarée dès maintenant : c'est le point d'entrée de tout invité
/// (EF-INV-01), et elle doit fonctionner en accès direct depuis un lien, sans passer par
/// l'accueil. Sur le web, cela suppose que le serveur renvoie index.html pour toute
/// route inconnue — voir app/nginx.conf.
abstract final class PpRoutes {
  static const accueil = '/';
  static const rejoindre = '/join/:token';
  static const rejoindreParCode = '/rejoindre';
  static const evenement = '/events/:eventId';
  static const profil = '/profil';

  static String versEvenement(String eventId) => '/events/$eventId';

  static String versRejoindre(String token) => '/join/$token';
}

GoRouter creerRouteur() => GoRouter(
  initialLocation: PpRoutes.accueil,
  routes: [
    GoRoute(
      path: PpRoutes.accueil,
      builder: (context, state) => const AccueilPage(),
    ),
    GoRoute(
      path: PpRoutes.rejoindre,
      builder: (context, state) =>
          RejoindrePage(token: state.pathParameters['token']),
    ),
    GoRoute(
      path: PpRoutes.rejoindreParCode,
      builder: (context, state) => const RejoindrePage(),
    ),
    GoRoute(
      path: PpRoutes.evenement,
      builder: (context, state) =>
          CoquilleEvenement(eventId: state.pathParameters['eventId']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          PpStrings.erreurIntrouvable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  ),
);
