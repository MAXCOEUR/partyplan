# partyplan_api.api.SettlementsApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancelSettlement**](SettlementsApi.md#cancelsettlement) | **DELETE** /v1/events/{eventId}/settlements/{settlementId} | Annule un marquage. La ligne subsiste, horodatée comme annulée.
[**getSettlements**](SettlementsApi.md#getsettlements) | **GET** /v1/events/{eventId}/settlements | Soldes, règlements proposés et règlements effectués.
[**markSettlement**](SettlementsApi.md#marksettlement) | **POST** /v1/events/{eventId}/settlements | Marque un remboursement comme effectué. En-tête Idempotency-Key obligatoire.


# **cancelSettlement**
> SettlementsPage cancelSettlement(eventId, settlementId)

Annule un marquage. La ligne subsiste, horodatée comme annulée.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getSettlementsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String settlementId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.cancelSettlement(eventId, settlementId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SettlementsApi->cancelSettlement: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **settlementId** | **String**|  | 

### Return type

[**SettlementsPage**](SettlementsPage.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSettlements**
> SettlementsPage getSettlements(eventId)

Soldes, règlements proposés et règlements effectués.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getSettlementsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getSettlements(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SettlementsApi->getSettlements: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**SettlementsPage**](SettlementsPage.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **markSettlement**
> SettlementsPage markSettlement(eventId, markSettlementBody)

Marque un remboursement comme effectué. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getSettlementsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final MarkSettlementBody markSettlementBody = ; // MarkSettlementBody | 

try {
    final response = api.markSettlement(eventId, markSettlementBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SettlementsApi->markSettlement: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **markSettlementBody** | [**MarkSettlementBody**](MarkSettlementBody.md)|  | 

### Return type

[**SettlementsPage**](SettlementsPage.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

