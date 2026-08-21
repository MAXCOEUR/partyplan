# partyplan_api.api.ExpensesApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createExpense**](ExpensesApi.md#createexpense) | **POST** /v1/events/{eventId}/expenses | Crée une dépense. En-tête Idempotency-Key obligatoire.
[**deleteExpense**](ExpensesApi.md#deleteexpense) | **DELETE** /v1/events/{eventId}/expenses/{expenseId} | Supprime une dépense. La trace subsiste, les soldes sont recalculés.
[**getExpense**](ExpensesApi.md#getexpense) | **GET** /v1/events/{eventId}/expenses/{expenseId} | Détail d&#39;une dépense : payeur, participants, part de chacun.
[**listExpenses**](ExpensesApi.md#listexpenses) | **GET** /v1/events/{eventId}/expenses | Dépenses de l&#39;événement, avec les totaux.
[**updateExpense**](ExpensesApi.md#updateexpense) | **PATCH** /v1/events/{eventId}/expenses/{expenseId} | Modifie une dépense. L&#39;état précédent est conservé.


# **createExpense**
> ExpenseDetail createExpense(eventId, expenseBody)

Crée une dépense. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getExpensesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ExpenseBody expenseBody = ; // ExpenseBody | 

try {
    final response = api.createExpense(eventId, expenseBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ExpensesApi->createExpense: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **expenseBody** | [**ExpenseBody**](ExpenseBody.md)|  | 

### Return type

[**ExpenseDetail**](ExpenseDetail.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteExpense**
> deleteExpense(eventId, expenseId)

Supprime une dépense. La trace subsiste, les soldes sont recalculés.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getExpensesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String expenseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.deleteExpense(eventId, expenseId);
} on DioException catch (e) {
    print('Exception when calling ExpensesApi->deleteExpense: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **expenseId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getExpense**
> ExpenseDetail getExpense(eventId, expenseId)

Détail d'une dépense : payeur, participants, part de chacun.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getExpensesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String expenseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getExpense(eventId, expenseId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ExpensesApi->getExpense: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **expenseId** | **String**|  | 

### Return type

[**ExpenseDetail**](ExpenseDetail.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listExpenses**
> ExpensesPage listExpenses(eventId)

Dépenses de l'événement, avec les totaux.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getExpensesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.listExpenses(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ExpensesApi->listExpenses: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**ExpensesPage**](ExpensesPage.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateExpense**
> ExpenseDetail updateExpense(eventId, expenseId, expenseBody)

Modifie une dépense. L'état précédent est conservé.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getExpensesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String expenseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ExpenseBody expenseBody = ; // ExpenseBody | 

try {
    final response = api.updateExpense(eventId, expenseId, expenseBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ExpensesApi->updateExpense: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **expenseId** | **String**|  | 
 **expenseBody** | [**ExpenseBody**](ExpenseBody.md)|  | 

### Return type

[**ExpenseDetail**](ExpenseDetail.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

