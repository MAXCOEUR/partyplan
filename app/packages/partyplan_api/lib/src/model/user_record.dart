//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'user_record.g.dart';

/// Vue d'un compte pour l'administration. Volontairement limitée aux données techniques nécessaires au support (RG-RGPD-04) : ni contenu d'événement, ni empreinte de mot de passe, ni secret de double authentification.
///
/// Properties:
/// * [id] 
/// * [email] 
/// * [displayName] 
/// * [avatarUrl] 
/// * [platformRole] - Rôle de portée « instance entière » (§3.1). Sans rapport avec EventMemberRole : un PlatformRole.PlatformAdmin n'a aucun droit dans un événement dont il n'est pas membre.
/// * [emailVerified] 
/// * [hasPassword] 
/// * [totpEnabled] 
/// * [googleLinked] 
/// * [appleLinked] 
/// * [isSuspended] 
/// * [suspensionReason] 
/// * [lastLoginAt] 
/// * [eventCount] 
/// * [activeSessionCount] 
/// * [createdAt] 
/// * [deletedAt] 
@BuiltValue()
abstract class UserRecord implements Built<UserRecord, UserRecordBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'email')
  String? get email;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'avatarUrl')
  String? get avatarUrl;

  /// Rôle de portée « instance entière » (§3.1). Sans rapport avec EventMemberRole : un PlatformRole.PlatformAdmin n'a aucun droit dans un événement dont il n'est pas membre.
  @BuiltValueField(wireName: r'platformRole')
  int get platformRole;

  @BuiltValueField(wireName: r'emailVerified')
  bool get emailVerified;

  @BuiltValueField(wireName: r'hasPassword')
  bool get hasPassword;

  @BuiltValueField(wireName: r'totpEnabled')
  bool get totpEnabled;

  @BuiltValueField(wireName: r'googleLinked')
  bool get googleLinked;

  @BuiltValueField(wireName: r'appleLinked')
  bool get appleLinked;

  @BuiltValueField(wireName: r'isSuspended')
  bool get isSuspended;

  @BuiltValueField(wireName: r'suspensionReason')
  String? get suspensionReason;

  @BuiltValueField(wireName: r'lastLoginAt')
  DateTime? get lastLoginAt;

  @BuiltValueField(wireName: r'eventCount')
  AdminListUsersPageParameter get eventCount;

  @BuiltValueField(wireName: r'activeSessionCount')
  AdminListUsersPageParameter get activeSessionCount;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'deletedAt')
  DateTime? get deletedAt;

  UserRecord._();

  factory UserRecord([void updates(UserRecordBuilder b)]) = _$UserRecord;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UserRecordBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UserRecord> get serializer => _$UserRecordSerializer();
}

class _$UserRecordSerializer implements PrimitiveSerializer<UserRecord> {
  @override
  final Iterable<Type> types = const [UserRecord, _$UserRecord];

  @override
  final String wireName = r'UserRecord';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UserRecord object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'email';
    yield object.email == null ? null : serializers.serialize(
      object.email,
      specifiedType: const FullType.nullable(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'avatarUrl';
    yield object.avatarUrl == null ? null : serializers.serialize(
      object.avatarUrl,
      specifiedType: const FullType.nullable(String),
    );
    yield r'platformRole';
    yield serializers.serialize(
      object.platformRole,
      specifiedType: const FullType(int),
    );
    yield r'emailVerified';
    yield serializers.serialize(
      object.emailVerified,
      specifiedType: const FullType(bool),
    );
    yield r'hasPassword';
    yield serializers.serialize(
      object.hasPassword,
      specifiedType: const FullType(bool),
    );
    yield r'totpEnabled';
    yield serializers.serialize(
      object.totpEnabled,
      specifiedType: const FullType(bool),
    );
    yield r'googleLinked';
    yield serializers.serialize(
      object.googleLinked,
      specifiedType: const FullType(bool),
    );
    yield r'appleLinked';
    yield serializers.serialize(
      object.appleLinked,
      specifiedType: const FullType(bool),
    );
    yield r'isSuspended';
    yield serializers.serialize(
      object.isSuspended,
      specifiedType: const FullType(bool),
    );
    yield r'suspensionReason';
    yield object.suspensionReason == null ? null : serializers.serialize(
      object.suspensionReason,
      specifiedType: const FullType.nullable(String),
    );
    yield r'lastLoginAt';
    yield object.lastLoginAt == null ? null : serializers.serialize(
      object.lastLoginAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'eventCount';
    yield serializers.serialize(
      object.eventCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'activeSessionCount';
    yield serializers.serialize(
      object.activeSessionCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'deletedAt';
    yield object.deletedAt == null ? null : serializers.serialize(
      object.deletedAt,
      specifiedType: const FullType.nullable(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UserRecord object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UserRecordBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.email = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'avatarUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.avatarUrl = valueDes;
          break;
        case r'platformRole':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.platformRole = valueDes;
          break;
        case r'emailVerified':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.emailVerified = valueDes;
          break;
        case r'hasPassword':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.hasPassword = valueDes;
          break;
        case r'totpEnabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.totpEnabled = valueDes;
          break;
        case r'googleLinked':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.googleLinked = valueDes;
          break;
        case r'appleLinked':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.appleLinked = valueDes;
          break;
        case r'isSuspended':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isSuspended = valueDes;
          break;
        case r'suspensionReason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.suspensionReason = valueDes;
          break;
        case r'lastLoginAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.lastLoginAt = valueDes;
          break;
        case r'eventCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.eventCount.replace(valueDes);
          break;
        case r'activeSessionCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.activeSessionCount.replace(valueDes);
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'deletedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.deletedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UserRecord deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UserRecordBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


