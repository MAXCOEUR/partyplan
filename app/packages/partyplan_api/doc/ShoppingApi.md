# partyplan_api.api.ShoppingApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**addShoppingItem**](ShoppingApi.md#addshoppingitem) | **POST** /v1/events/{eventId}/shopping | Ajoute un article. En-tête Idempotency-Key obligatoire.
[**claimShoppingItem**](ShoppingApi.md#claimshoppingitem) | **POST** /v1/events/{eventId}/shopping/{itemId}/claim | S&#39;attribue un article. Attribution unique, contrôlée en base.
[**deleteShoppingItem**](ShoppingApi.md#deleteshoppingitem) | **DELETE** /v1/events/{eventId}/shopping/{itemId} | Supprime un article. Refusé si une dépense y est rattachée.
[**listShoppingItems**](ShoppingApi.md#listshoppingitems) | **GET** /v1/events/{eventId}/shopping | Liste de courses et avancement.
[**purchaseShoppingItem**](ShoppingApi.md#purchaseshoppingitem) | **POST** /v1/events/{eventId}/shopping/{itemId}/purchase | Déclare l&#39;achat. La saisie d&#39;un prix payé engendre la dépense.
[**releaseShoppingItem**](ShoppingApi.md#releaseshoppingitem) | **DELETE** /v1/events/{eventId}/shopping/{itemId}/claim | Retire son attribution.
[**updateShoppingItem**](ShoppingApi.md#updateshoppingitem) | **PATCH** /v1/events/{eventId}/shopping/{itemId} | Modifie un article.


# **addShoppingItem**
> ShoppingItemView addShoppingItem(eventId, shoppingItemBody)

Ajoute un article. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ShoppingItemBody shoppingItemBody = ; // ShoppingItemBody | 

try {
    final response = api.addShoppingItem(eventId, shoppingItemBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->addShoppingItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **shoppingItemBody** | [**ShoppingItemBody**](ShoppingItemBody.md)|  | 

### Return type

[**ShoppingItemView**](ShoppingItemView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **claimShoppingItem**
> ShoppingItemView claimShoppingItem(eventId, itemId)

S'attribue un article. Attribution unique, contrôlée en base.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.claimShoppingItem(eventId, itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->claimShoppingItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **itemId** | **String**|  | 

### Return type

[**ShoppingItemView**](ShoppingItemView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteShoppingItem**
> deleteShoppingItem(eventId, itemId)

Supprime un article. Refusé si une dépense y est rattachée.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.deleteShoppingItem(eventId, itemId);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->deleteShoppingItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **itemId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listShoppingItems**
> ShoppingList listShoppingItems(eventId)

Liste de courses et avancement.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.listShoppingItems(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->listShoppingItems: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**ShoppingList**](ShoppingList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **purchaseShoppingItem**
> ShoppingItemView purchaseShoppingItem(eventId, itemId, purchaseBody)

Déclare l'achat. La saisie d'un prix payé engendre la dépense.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final PurchaseBody purchaseBody = ; // PurchaseBody | 

try {
    final response = api.purchaseShoppingItem(eventId, itemId, purchaseBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->purchaseShoppingItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **itemId** | **String**|  | 
 **purchaseBody** | [**PurchaseBody**](PurchaseBody.md)|  | 

### Return type

[**ShoppingItemView**](ShoppingItemView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **releaseShoppingItem**
> ShoppingItemView releaseShoppingItem(eventId, itemId)

Retire son attribution.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.releaseShoppingItem(eventId, itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->releaseShoppingItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **itemId** | **String**|  | 

### Return type

[**ShoppingItemView**](ShoppingItemView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateShoppingItem**
> ShoppingItemView updateShoppingItem(eventId, itemId, shoppingItemBody)

Modifie un article.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getShoppingApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ShoppingItemBody shoppingItemBody = ; // ShoppingItemBody | 

try {
    final response = api.updateShoppingItem(eventId, itemId, shoppingItemBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ShoppingApi->updateShoppingItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **itemId** | **String**|  | 
 **shoppingItemBody** | [**ShoppingItemBody**](ShoppingItemBody.md)|  | 

### Return type

[**ShoppingItemView**](ShoppingItemView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

