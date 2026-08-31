import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/bandeau_notification.dart';
import '../core/notifications/notification_recue.dart';
import '../core/notifications/regle_affichage_premier_plan.dart';
import '../core/notifications/zone_visible.dart';
import '../core/providers.dart';
import '../design/components/pp_bandeau_notification.dart';
import '../design/theme.dart';
import '../l10n/generated/pp_localisations.dart';
import '../l10n/marque.dart';
import 'router.dart';

/// Racine de l'application.
class PartyPlanApp extends ConsumerStatefulWidget {
  const PartyPlanApp({super.key});

  /// Délégués de localisation, partagés avec les tests pour qu'ils montent la même
  /// application que la production.
  ///
  /// Les libellés Cupertino sont inclus bien qu'aucun écran ne s'en serve : le framework
  /// vérifie qu'un délégué couvre chaque langue déclarée, et leur absence fait échouer
  /// tout test de widget. C'est aussi pourquoi `cupertino_icons` figure en dépendance.
  static const delegues = <LocalizationsDelegate<Object>>[
    PpL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const languesPrisesEnCharge = <Locale>[Locale('fr')];

  @override
  ConsumerState<PartyPlanApp> createState() => _PartyPlanAppState();
}

class _PartyPlanAppState extends ConsumerState<PartyPlanApp> {
  @override
  void initState() {
    super.initState();

    // Posées une seule fois, et non dans build : rappelé à chaque reconstruction, il
    // empilerait les abonnements, et une notification tapée provoquerait autant de
    // navigations.
    final service = ref.read(serviceNotificationsProvider);
    final routeur = ref.read(routeurProvider);

    _sansBruit(service.ecouterRafraichissements);
    _sansBruit(() => service.ecouterOuvertures(routeur.go));
    _sansBruit(() => service.ecouterPremierPlan(_annoncer));
  }

  /// Inscrit l'appareil dès qu'une session existe, et à chaque fois qu'elle revient.
  ///
  /// Adossé à l'état de session, et non au lancement : sur une installation neuve,
  /// l'application démarre sans session, présente l'écran de connexion, et n'est
  /// connectée qu'ensuite. Un jeton envoyé au lancement partait donc avant toute
  /// session, se faisait refuser en silence, et rien ne le rattrapait avant le
  /// lancement suivant — une personne qui installe puis se connecte n'avait aucune
  /// notification de toute sa première session.
  /// Une session déjà ouverte au lancement est captée elle aussi : l'état passe par
  /// « en cours de détermination » avant d'être connu, ce qui est bien un changement.
  void _inscrireQuandConnecte() {
    ref.listen(sessionProvider, (precedent, etat) {
      if (etat.value == EtatSession.connecte &&
          precedent?.value != EtatSession.connecte) {
        _sansBruit(ref.read(serviceNotificationsProvider).reinscrireAppareil);
      }
    });
  }

  /// Lance une tâche de notification sans l'attendre et sans la laisser remonter.
  ///
  /// Deux raisons, et les deux comptent. L'application ne doit pas retarder son premier
  /// affichage pour une écoute de notifications ; et une tâche lancée sans être attendue
  /// fait remonter son échec jusqu'au gestionnaire d'erreurs global, où il devient une
  /// erreur de l'application entière. Rien de ce qui touche aux notifications ne doit
  /// aller jusque-là : perdre l'avis vaut mieux que salir le démarrage.
  static void _sansBruit(Future<void> Function() tache) {
    unawaited(tache().catchError((Object _) {}));
  }

  /// Décide du sort d'une notification reçue alors que l'application est ouverte.
  ///
  /// Le tri se fait ici, en un seul endroit, plutôt que dans le bandeau : celui-ci
  /// affiche ce qu'on lui donne, et la règle s'éprouve sans monter d'application.
  void _annoncer(NotificationRecue recue) {
    if (!mounted) {
      return;
    }

    final zone = ZoneVisible.composer(
      // `matchedLocation` et non `uri` : la seconde porte les paramètres de requête,
      // qui feraient échouer toute comparaison de chemin.
      chemin: ref.read(routeurProvider).state.matchedLocation,
      publie: ref.read(ongletEvenementProvider),
    );

    if (RegleAffichagePremierPlan.doitAfficher(recue, zone)) {
      ref.read(bandeauNotificationProvider.notifier).montrer(recue);
    }
  }

  @override
  Widget build(BuildContext context) {
    _inscrireQuandConnecte();

    return MaterialApp.router(
      title: PpMarque.nom,
      debugShowCheckedModeBanner: false,
      // Le français est la seule langue livrée ; les délégués sont posés dès maintenant
      // pour que les libellés de Material soient traduits eux aussi.
      localizationsDelegates: PartyPlanApp.delegues,
      supportedLocales: PartyPlanApp.languesPrisesEnCharge,
      locale: const Locale('fr'),
      theme: PpTheme.clair(),
      darkTheme: PpTheme.sombre(),
      routerConfig: ref.watch(routeurProvider),
      // Posé au-dessus de tous les écrans, une seule fois : une notification peut arriver
      // n'importe où, et la poser écran par écran en oublierait.
      builder: (context, enfant) => PpBandeauNotification(
        aller: ref.read(routeurProvider).go,
        child: enfant ?? const SizedBox.shrink(),
      ),
    );
  }
}
