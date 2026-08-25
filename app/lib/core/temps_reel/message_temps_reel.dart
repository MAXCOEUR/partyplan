/// Un changement diffusé par le serveur (§9).
///
/// Le nom est comparé littéralement aux constantes du serveur : c'est un contrat de
/// chaînes, et le client déployé ne peut pas être mis à jour en même temps que l'API.
class MessageTempsReel {
  const MessageTempsReel({required this.nom, this.charge});

  final String nom;

  /// État résultant de la ressource. Inutilisé pour l'instant : le client invalide et
  /// relit par REST plutôt que de rapiécer son état local. Conservé parce que le
  /// serveur l'envoie déjà et que le rapiéçage viendra sans toucher au serveur.
  final Object? charge;

  /// Familles de messages, pour décider quoi invalider sans énumérer les vingt et un.
  bool get toucheMembres => nom.startsWith('member.');
  bool get toucheCourses => nom.startsWith('item.');
  bool get toucheDepenses => nom.startsWith('expense.');
  bool get toucheSoldes =>
      nom == 'balances.changed' || nom.startsWith('settlement.');
  bool get toucheDiscussion => nom.startsWith('message.');
  bool get toucheSondages => nom.startsWith('poll.');
  bool get toucheEvenement => nom == 'event.updated';
}
