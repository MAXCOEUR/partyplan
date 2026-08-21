# partyplan_api.api.InvitationsApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**joinByShortCode**](InvitationsApi.md#joinbyshortcode) | **POST** /v1/join/code/{shortCode} | Rejoint depuis un code court. En-tête Idempotency-Key obligatoire.
[**joinEvent**](InvitationsApi.md#joinevent) | **POST** /v1/join/{token} | Rejoint l&#39;événement. Aucun compte n&#39;est exigé. En-tête Idempotency-Key obligatoire.
[**previewByShortCode**](InvitationsApi.md#previewbyshortcode) | **GET** /v1/join/code/{shortCode} | Résolution d&#39;un code court PLAN-XXXXXX.
[**previewInvitation**](InvitationsApi.md#previewinvitation) | **GET** /v1/join/{token} | Aperçu restreint : nom, date, lieu, nombre de participants.


# **joinByShortCode**
> JoinResult joinByShortCode(shortCode, joinBody)

Rejoint depuis un code court. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getInvitationsApi();
final String shortCode = shortCode_example; // String | 
final JoinBody joinBody = ; // JoinBody | 

try {
    final response = api.joinByShortCode(shortCode, joinBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling InvitationsApi->joinByShortCode: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **shortCode** | **String**|  | 
 **joinBody** | [**JoinBody**](JoinBody.md)|  | 

### Return type

[**JoinResult**](JoinResult.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **joinEvent**
> JoinResult joinEvent(token, joinBody)

Rejoint l'événement. Aucun compte n'est exigé. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getInvitationsApi();
final String token = token_example; // String | 
final JoinBody joinBody = ; // JoinBody | 

try {
    final response = api.joinEvent(token, joinBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling InvitationsApi->joinEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **token** | **String**|  | 
 **joinBody** | [**JoinBody**](JoinBody.md)|  | 

### Return type

[**JoinResult**](JoinResult.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewByShortCode**
> JoinPreview previewByShortCode(shortCode)

Résolution d'un code court PLAN-XXXXXX.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getInvitationsApi();
final String shortCode = shortCode_example; // String | 

try {
    final response = api.previewByShortCode(shortCode);
    print(response);
} on DioException catch (e) {
    print('Exception when calling InvitationsApi->previewByShortCode: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **shortCode** | **String**|  | 

### Return type

[**JoinPreview**](JoinPreview.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewInvitation**
> JoinPreview previewInvitation(token)

Aperçu restreint : nom, date, lieu, nombre de participants.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getInvitationsApi();
final String token = token_example; // String | 

try {
    final response = api.previewInvitation(token);
    print(response);
} on DioException catch (e) {
    print('Exception when calling InvitationsApi->previewInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **token** | **String**|  | 

### Return type

[**JoinPreview**](JoinPreview.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

