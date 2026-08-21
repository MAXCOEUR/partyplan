import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for ShoppingApi
void main() {
  final instance = PartyplanApi().getShoppingApi();

  group(ShoppingApi, () {
    // Ajoute un article. En-tête Idempotency-Key obligatoire.
    //
    //Future<ShoppingItemView> addShoppingItem(String eventId, ShoppingItemBody shoppingItemBody) async
    test('test addShoppingItem', () async {
      // TODO
    });

    // S'attribue un article. Attribution unique, contrôlée en base.
    //
    //Future<ShoppingItemView> claimShoppingItem(String eventId, String itemId) async
    test('test claimShoppingItem', () async {
      // TODO
    });

    // Supprime un article. Refusé si une dépense y est rattachée.
    //
    //Future deleteShoppingItem(String eventId, String itemId) async
    test('test deleteShoppingItem', () async {
      // TODO
    });

    // Liste de courses et avancement.
    //
    //Future<ShoppingList> listShoppingItems(String eventId) async
    test('test listShoppingItems', () async {
      // TODO
    });

    // Déclare l'achat. La saisie d'un prix payé engendre la dépense.
    //
    //Future<ShoppingItemView> purchaseShoppingItem(String eventId, String itemId, PurchaseBody purchaseBody) async
    test('test purchaseShoppingItem', () async {
      // TODO
    });

    // Retire son attribution.
    //
    //Future<ShoppingItemView> releaseShoppingItem(String eventId, String itemId) async
    test('test releaseShoppingItem', () async {
      // TODO
    });

    // Modifie un article.
    //
    //Future<ShoppingItemView> updateShoppingItem(String eventId, String itemId, ShoppingItemBody shoppingItemBody) async
    test('test updateShoppingItem', () async {
      // TODO
    });

  });
}
