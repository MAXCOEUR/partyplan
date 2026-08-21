# partyplan_api.model.UserRecord

## Load the model package
```dart
import 'package:partyplan_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | 
**email** | **String** |  | 
**displayName** | **String** |  | 
**avatarUrl** | **String** |  | 
**platformRole** | **int** | Rôle de portée « instance entière » (§3.1). Sans rapport avec EventMemberRole : un PlatformRole.PlatformAdmin n'a aucun droit dans un événement dont il n'est pas membre. | 
**emailVerified** | **bool** |  | 
**hasPassword** | **bool** |  | 
**totpEnabled** | **bool** |  | 
**googleLinked** | **bool** |  | 
**appleLinked** | **bool** |  | 
**isSuspended** | **bool** |  | 
**suspensionReason** | **String** |  | 
**lastLoginAt** | [**DateTime**](DateTime.md) |  | 
**eventCount** | [**AdminListUsersPageParameter**](AdminListUsersPageParameter.md) |  | 
**activeSessionCount** | [**AdminListUsersPageParameter**](AdminListUsersPageParameter.md) |  | 
**createdAt** | [**DateTime**](DateTime.md) |  | 
**deletedAt** | [**DateTime**](DateTime.md) |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


