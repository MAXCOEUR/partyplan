import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for EventsApi
void main() {
  final instance = PartyplanApi().getEventsApi();

  group(EventsApi, () {
    // Crée un événement. En-tête Idempotency-Key obligatoire.
    //
    //Future<EventSummary> createEvent(CreateEventBody createEventBody) async
    test('test createEvent', () async {
      // TODO
    });

    // Supprime l'événement. Confirmation renforcée exigée par « force ».
    //
    //Future deleteEvent(String eventId, { bool force }) async
    test('test deleteEvent', () async {
      // TODO
    });

    // Synthèse d'un événement dont l'appelant est membre.
    //
    //Future<EventSummary> getEvent(String eventId) async
    test('test getEvent', () async {
      // TODO
    });

    // Lien, code court et état d'ouverture de l'événement.
    //
    //Future<EventInvitation> getInvitation(String eventId) async
    test('test getInvitation', () async {
      // TODO
    });

    // Événements de l'appelant, à venir puis passés.
    //
    //Future<BuiltList<EventListItem>> listEvents() async
    test('test listEvents', () async {
      // TODO
    });

    // Régénère lien et code court. Les précédents deviennent invalides.
    //
    //Future<EventInvitation> rotateInvitation(String eventId) async
    test('test rotateInvitation', () async {
      // TODO
    });

    // Ouvre ou ferme les nouvelles arrivées.
    //
    //Future setJoinEnabled(String eventId, JoinEnabledBody joinEnabledBody) async
    test('test setJoinEnabled', () async {
      // TODO
    });

    // Modifie l'événement. Un changement de date ou de lieu est journalisé.
    //
    //Future<EventSummary> updateEvent(String eventId, UpdateEventBody updateEventBody) async
    test('test updateEvent', () async {
      // TODO
    });

  });
}
