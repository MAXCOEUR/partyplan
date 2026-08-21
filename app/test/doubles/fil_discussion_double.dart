import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/core/providers.dart';

/// Fil de discussion arrêté, pour les écrans dont la discussion n'est pas l'objet.
///
/// Le notifieur réel demande une page à l'API : celui-ci rend ce qu'on lui donne, sans
/// réseau ni pagination.
class FilFige extends FilDiscussionNotifier {
  FilFige(this.fil) : super('fil-fige');

  final FilDiscussion fil;

  @override
  Future<FilDiscussion> build() async => fil;
}

/// Fil dont le chargement échoue, pour vérifier ce que l'écran montre alors.
class FilEnPanne extends FilDiscussionNotifier {
  FilEnPanne() : super('fil-en-panne');

  @override
  Future<FilDiscussion> build() => Future.error(Exception('réseau'));
}
